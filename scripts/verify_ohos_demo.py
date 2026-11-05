#!/usr/bin/env python3
"""Exercise the installed native HarmonyOS Demo through real UI input (debug HAP)."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
BUNDLE = 'com.mxlogger.ohos.poc'


class Demo:
    def __init__(self, hdc, device, output):
        self.hdc = [str(hdc), '-t', device]
        self.output = output
        self.output.mkdir(parents=True, exist_ok=True)
        self.steps = []
        self.nodes = []
        self.height = 2760
        self.width = 1256

    def run(self, *args):
        result = subprocess.run(self.hdc + list(map(str, args)), capture_output=True, text=True, timeout=25)
        if result.returncode or '[Fail]' in result.stdout:
            raise RuntimeError(result.stdout + result.stderr)
        return result.stdout

    def dump(self):
        path = '/data/local/tmp/mxlogger-demo-ui.json'
        self.run('shell', 'uitest', 'dumpLayout', '-b', BUNDLE, '-p', path)
        self.run('file', 'recv', path, self.output / 'layout.json')
        tree = json.loads((self.output / 'layout.json').read_text())
        self.nodes = []

        def walk(node):
            self.nodes.append(node['attributes'])
            for child in node.get('children', []):
                walk(child)
        walk(tree)
        bounds = self.bounds(self.nodes[0])
        if bounds[2] > 0 and bounds[3] > 0:
            self.width, self.height = bounds[2], bounds[3]
        return self.nodes

    @staticmethod
    def bounds(node):
        return list(map(int, re.findall(r'-?\d+', node['bounds'])))

    def find(self, key, value, prefix=False):
        for node in self.nodes:
            if (node.get(key, '').startswith(value) if prefix else node.get(key) == value):
                b = self.bounds(node)
                if len(b) == 4 and b[2] > b[0] and b[3] > b[1] and b[1] >= 100 and b[3] < self.height - 60:
                    return node
        return None

    def click(self, identifier=None, text=None, prefix=False, scroll=False):
        key, value = ('id', identifier) if identifier else ('text', text)
        node = None
        previous = None
        down = True
        for _ in range(28 if scroll else 3):
            self.dump()
            node = self.find(key, value, prefix)
            if node:
                break
            if scroll:
                visible = tuple(n.get('id') for n in self.nodes if n.get('id'))
                if visible == previous:
                    down = not down
                previous = visible
                self.swipe(down)
            else:
                time.sleep(0.3)
        if not node:
            raise AssertionError('UI control not found: ' + str(value))
        left, top, right, bottom = self.bounds(node)
        self.run('shell', 'uitest', 'uiInput', 'click', (left + right) // 2, (top + bottom) // 2)
        self.steps.append('tap ' + str(value))
        (self.output / 'steps.json').write_text(json.dumps(self.steps, ensure_ascii=False, indent=2))
        time.sleep(0.15)

    def swipe(self, down):
        self.run('shell', 'uitest', 'uiInput', 'swipe', self.width // 2,
                 int(self.height * (0.75 if down else 0.40)), self.width // 2,
                 int(self.height * (0.40 if down else 0.75)), 1600)

    def top(self):
        for _ in range(14):
            self.swipe(False)

    def text(self, value, timeout=6):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            self.dump()
            if any(value in node.get('text', '') for node in self.nodes):
                self.steps.append('see ' + value)
                return
            time.sleep(0.2)
        raise AssertionError('Expected UI text: ' + value)

    def screenshot(self, name):
        path = '/data/local/tmp/mxlogger-demo-' + name + '.jpeg'
        self.run('shell', 'snapshot_display', '-f', path)
        self.run('file', 'recv', path, self.output / (name + '.jpeg'))

    def back(self):
        self.click('demo.back')

    def search_and_language(self):
        self.click('demo.language')
        self.text('WRITE LOGS')
        self.text('Write Debug')
        self.click('demo.language')
        self.click('demo.files', scroll=True)
        self.click('demo.file.', prefix=True)
        self.click('demo.record.0')
        self.click(text='复制 JSON')
        self.dump()
        node = self.find('id', 'demo.search')
        if not node:
            raise AssertionError('Search field missing')
        left, top, right, bottom = self.bounds(node)
        self.run('shell', 'uitest', 'uiInput', 'inputText', (left + right) // 2,
                 (top + bottom) // 2, 'NoSuchRecord_demo_ui_987654321')
        self.run('shell', 'uitest', 'uiInput', 'keyEvent', 'Back')
        self.text('没有匹配的日志')
        self.screenshot('search')
        self.back()
        self.back()
        self.top()

    def main(self):
        self.run('shell', 'aa', 'force-stop', BUNDLE)
        self.run('shell', 'aa', 'start', '-b', BUNDLE, '-a', 'EntryAbility')
        self.click('demo.landingLanguage')
        self.text('Explore Demo')
        self.click('demo.landingLanguage')
        self.screenshot('welcome')
        self.click('demo.enter')
        self.screenshot('home')
        for level in range(5):
            self.click('demo.write.' + str(level), scroll=True)
        self.click('demo.network', scroll=True)
        self.click('demo.tokenWrite', scroll=True)
        self.click('demo.custom', scroll=True)
        self.click('demo.customSubmit')
        self.back()
        self.text('日志已写入')
        self.click('demo.level', scroll=True)
        self.click(text='Warn')
        self.top()
        self.click('demo.write.0')
        self.text('本条已过滤')
        self.click('demo.level', scroll=True)
        self.click(text='Debug')
        self.click('demo.enable', scroll=True)
        self.top()
        self.click('demo.write.1')
        self.text('本条未保存')
        self.click('demo.enable', scroll=True)
        self.click('demo.console', scroll=True)
        self.click('demo.console', scroll=True)
        self.click('demo.age', scroll=True)
        self.click(text='1 day')
        self.text('保留时长 · 1 天')
        self.click('demo.maxSize', scroll=True)
        self.click(text='50 MB')
        self.text('大小上限 · 50.00 MB')
        self.click('demo.workers', scroll=True)
        self.text('4 Worker', timeout=25)
        self.click('demo.benchmark', scroll=True)
        self.text('100000 条', timeout=65)
        self.click('demo.files', scroll=True)
        self.text('AES-CFB-128')
        self.screenshot('files')
        self.click('demo.file.', prefix=True)
        self.text('Worker')
        self.screenshot('records')
        self.click('demo.next')
        self.text('第 2/')
        self.click('demo.previous')
        self.click('demo.record.0')
        self.text('isMainThread')
        self.click(text='关闭')
        self.click('demo.recordLevel')
        self.click(text='Fatal')
        self.text('Fatal')
        self.back()
        self.back()
        self.click('demo.flush', scroll=True)
        for identifier in ('demo.expire', 'demo.before', 'demo.removeAll'):
            self.click(identifier, scroll=True)
            self.click(text='确认')
            self.text('操作完成')
        self.click('demo.attach', scroll=True)
        self.text('日志已写入')
        self.click('demo.state', scroll=True)
        self.text('isValid: true')
        self.click(text='OK')
        self.click('demo.destroy', scroll=True)
        self.click(text='确认')
        self.click('demo.state', scroll=True)
        self.text('isValid: false')
        self.click(text='OK')
        # Reinitialize using the explicit-directory API and plaintext daily policy.
        self.top()
        self.click('demo.initialize', scroll=True)
        self.click('demo.initPolicy', scroll=True)
        self.click(text='按天', prefix=True)
        self.click('demo.initEncrypted', scroll=True)
        self.click('demo.initDirectoryAPI', scroll=True)
        self.click('demo.initSubmit', scroll=True)
        self.top()
        self.text('PLAIN')
        self.text('按天')
        self.click('demo.write.1')
        self.click('demo.files', scroll=True)
        self.text('Plain')
        self.click('demo.file.', prefix=True)
        self.text('Info')
        self.screenshot('plaintext-records')
        self.back()
        self.back()
        # Leave the Demo in the same hourly/AES state as the other platform demos.
        self.top()
        self.click('demo.initialize', scroll=True)
        self.click('demo.initPolicy', scroll=True)
        self.click(text='按小时', prefix=True)
        self.click('demo.initEncrypted', scroll=True)
        self.click('demo.initDirectoryAPI', scroll=True)
        self.click('demo.initSubmit', scroll=True)
        self.top()
        self.text('AES')
        self.search_and_language()
        self.screenshot('home')
        report = {'passed': True, 'steps': self.steps, 'package': BUNDLE}
        (self.output / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
        print('PASS: native Demo UI, configuration, Workers, files, records, lifecycle and plaintext/AES initialization')
        print('Report: ' + str(self.output / 'report.json'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--hdc', type=Path, default=Path('/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'))
    args = parser.parse_args()
    demo = Demo(args.hdc, args.device, ROOT / 'build/ohos-sdk/demo-ui' / time.strftime('%Y%m%d-%H%M%S'))
    try:
        demo.main()
    except Exception:
        (demo.output / 'failed-steps.json').write_text(json.dumps(demo.steps, ensure_ascii=False, indent=2))
        raise


if __name__ == '__main__':
    main()
