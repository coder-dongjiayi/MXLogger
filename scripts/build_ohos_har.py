#!/usr/bin/env python3
"""Build a versioned OHPM HAR in an isolated project; never publish it."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sys
import tarfile
import tempfile
from urllib.parse import urlsplit

import verify_ohos_sdk as sdk

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / 'platform/OHOS'


def version_argument(value):
    pattern = r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?'
    match = re.fullmatch(pattern, value)
    if not match or (match[4] and any(part.isdigit() and len(part) > 1 and part[0] == '0'
                                    for part in match[4].split('.'))):
        raise argparse.ArgumentTypeError('版本号必须符合 SemVer，例如 2.3.0 或 2.3.0-beta.1')
    return value


def deveco_path():
    path = Path(os.environ.get('DEVECO_HOME', '/Applications/DevEco-Studio.app/Contents')).expanduser().resolve()
    if path.suffix == '.app':
        path = path / 'Contents'
    for name in ('tools/node/bin/node', 'tools/ohpm/bin/pm-cli.js',
                 'tools/hvigor/hvigor/bin/hvigor.js', 'sdk/default/openharmony/native/llvm/bin/llvm-nm'):
        if not (path / name).is_file():
            raise RuntimeError('未找到 DevEco 工具：' + str(path / name) + '\n请通过 DEVECO_HOME 指定 DevEco 安装目录。')
    return path


def validate_publish_metadata(package):
    # The local OHPM client accepts a missing author; the central registry rejects it.
    author = package.get('author')
    if not isinstance(author, dict) or not isinstance(author.get('name'), str) or not author['name'].strip():
        raise RuntimeError('OHPM 发布必须填写 author 对象及非空 author.name')
    if len(author['name']) > 128:
        raise RuntimeError('author.name 不能超过 128 个字符')
    email = author.get('email')
    if email is not None and (not isinstance(email, str) or len(email) > 64 or
                              not re.fullmatch(r'[a-zA-Z0-9_\-.]+@[a-zA-Z0-9_\-.]+', email)):
        raise RuntimeError('author.email 格式无效')
    keywords = package.get('keywords')
    if (not isinstance(keywords, list) or not 1 <= len(keywords) <= 10 or
            any(not isinstance(word, str) or not word.strip() or len(word) > 20 for word in keywords)):
        raise RuntimeError('OHPM 发布必须填写 keywords：1–10 项，每项 1–20 个字符')
    homepage = package.get('homepage')
    if not isinstance(homepage, str):
        raise RuntimeError('OHPM 发布必须填写 homepage 项目主页')
    url = urlsplit(homepage)
    if url.scheme not in ('https', 'http') or not url.hostname:
        raise RuntimeError('homepage 必须是有效的 HTTP(S) 项目主页地址')


def stage_project(work, version):
    project = work / 'source/platform/OHOS'
    project.mkdir(parents=True)
    ignore = shutil.ignore_patterns('build', '.cxx', '.hvigor', '.idea', 'oh_modules',
                                    'node_modules', 'oh-package-lock.json5', 'BuildProfile.ets', '__pycache__')
    shutil.copytree(ROOT / 'Core', work / 'source/Core', ignore=ignore)
    shutil.copy2(ROOT / 'LICENSE.TXT', work / 'source/LICENSE.TXT')
    for directory in ('AppScope', 'hvigor', 'mxlogger'):
        shutil.copytree(PROJECT / directory, project / directory, ignore=ignore)
    for filename in ('hvigorfile.ts', 'oh-package.json5'):
        shutil.copy2(PROJECT / filename, project / filename)
    # Use only the public template. A HAR needs no device certificate or app signing configuration.
    profile = json.loads((PROJECT / 'build-profile.template.json5').read_text())
    profile['app']['signingConfigs'] = []
    profile['modules'] = [module for module in profile['modules'] if module['name'] == 'mxlogger']
    if len(profile['modules']) != 1:
        raise RuntimeError('公开构建模板必须包含 mxlogger 模块')
    (project / 'build-profile.json5').write_text(json.dumps(profile, indent=2) + '\n')
    manifest_file = project / 'mxlogger/oh-package.json5'
    manifest = json.loads(manifest_file.read_text())
    manifest['version'] = version
    validate_publish_metadata(manifest)
    manifest_file.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    # Always distribute the current root license, including bundled third-party notices.
    shutil.copy2(ROOT / 'LICENSE.TXT', project / 'mxlogger/LICENSE.TXT')
    return project, manifest


def inspect_har(har, manifest):
    with tarfile.open(har) as archive:
        members = {member.name: member for member in archive.getmembers()}
        package = json.loads(archive.extractfile('package/oh-package.json5').read())
        validate_publish_metadata(package)
        if (package['name'], package['version']) != (manifest['name'], manifest['version']):
            raise RuntimeError('HAR 内部包名或版本号与参数不一致')
        for name in ('README.md', 'CHANGELOG.md', 'LICENSE.TXT'):
            entry = archive.extractfile('package/' + name)
            if entry is None or not entry.read().strip():
                raise RuntimeError('HAR 缺少非空发布文件：' + name)
        for name in ('example/README.md', 'example/Index.ets'):
            member = members.get('package/' + name)
            if member is None or not member.isfile():
                raise RuntimeError('HAR 缺少 example 示例文件：' + name)
            content = archive.extractfile(member).read()
            source = PROJECT / 'mxlogger' / name
            if not content.strip() or content != source.read_bytes():
                raise RuntimeError('HAR 中的 example 与示例源码不一致：' + name)
        types = package.get('types') or package.get('main')
        if not types or 'package/' + types not in members:
            raise RuntimeError('HAR 缺少公开 API 入口声明')
        if package.get('metadata', {}).get('debug') is not False:
            raise RuntimeError('必须构建 Release HAR')
        for name in members:
            path = Path(name)
            if (path.is_absolute() or '..' in path.parts or
                    any(part in ('.hvigor', '.cxx', 'node_modules', 'oh_modules', '.git') for part in path.parts) or
                    path.name in ('local.properties', '.ohpmrc', 'build-profile.json5') or
                    path.suffix.lower() in ('.p12', '.p7b', '.cer', '.pem', '.key')):
                raise RuntimeError('HAR 包含不应分发的文件：' + name)
        return package


def build(version):
    deveco = deveco_path()
    output = ROOT / 'build/ohos-release' / version
    output.mkdir(parents=True, exist_ok=True)
    work_root = ROOT / 'build/ohos-release/.work'
    work_root.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix=version + '-', dir=work_root))
    package_name = json.loads((PROJECT / 'mxlogger/oh-package.json5').read_text())['name']
    print('构建 ' + package_name + ' ' + version + '（Release · ARM64 / x86_64）', flush=True)
    print('构建日志目录：' + str(work), flush=True)
    try:
        project, manifest = stage_project(work, version)
        sdk.poc.PROJECT = project
        sdk.OUTPUT = work / 'artifacts'
        sdk.OUTPUT.mkdir()
        sdk.poc.OUTPUT = sdk.OUTPUT
        har = sdk.build_har(deveco)
        package = inspect_har(har, manifest)
        result = sdk.poc.run([deveco / 'tools/node/bin/node', deveco / 'tools/ohpm/bin/pm-cli.js',
                              'prepublish', har], cwd=project, env=sdk.poc.environment(deveco),
                             log=sdk.OUTPUT / 'prepublish.log')
        if 'prepublish ' + manifest['name'] + ' ' + version + ' succeed' not in result:
            raise RuntimeError('OHPM 未确认 prepublish 成功：\n' + result)
        print('PASS: OHPM prepublish 本地内容校验', flush=True)
        core_version = re.search(r'#define MXLOGGER_CORE_VERSION "([^"]+)"',
                                 (work / 'source/Core/mxlogger_version.hpp').read_text())[1]
        # Publish local output only after all build/package checks succeed.
        destination = output / har.name
        temporary = output / (har.name + '.tmp')
        shutil.copy2(har, temporary)
        temporary.replace(destination)
        digest = hashlib.sha256(destination.read_bytes()).hexdigest()
        (output / (har.name + '.sha256')).write_text(digest + '  ' + har.name + '\n')
        for name in ('prepublish.log', 'har-contents.txt'):
            shutil.copy2(sdk.OUTPUT / name, output / name)
        shutil.copy2(project / 'build/assembleHar-release.log', output / 'build.log')
        shutil.copytree(sdk.OUTPUT / 'har-libs', output / 'har-libs', dirs_exist_ok=True)
        report = {'name': package['name'], 'version': version, 'coreVersion': core_version,
                  'author': package['author'], 'keywords': package['keywords'],
                  'homepage': package['homepage'], 'exampleFiles': ['example/README.md', 'example/Index.ets'],
                  'har': str(destination), 'sha256': digest, 'buildMode': 'release',
                  'architectures': ['arm64-v8a', 'x86_64'], 'prepublishPassed': True,
                  'published': False}
        (output / 'release-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
        print('HAR：' + str(destination), flush=True)
        print('SHA256：' + digest, flush=True)
        print('发布命令（配置 OHPM 认证后手动执行）：\nohpm publish "' + str(destination) + '"', flush=True)
    except Exception:
        print('构建失败，保留诊断目录：' + str(work), file=sys.stderr)
        raise
    else:
        shutil.rmtree(work)


def main():
    parser = argparse.ArgumentParser(description=__doc__, usage='sh scripts/ohos_release.sh VERSION')
    parser.add_argument('version', type=version_argument, help='OHPM 包版本，例如 2.3.0')
    args = parser.parse_args()
    try:
        build(args.version)
    except (RuntimeError, OSError, ValueError) as error:
        parser.exit(1, '错误：' + str(error) + '\n')


if __name__ == '__main__':
    main()
