#!/bin/bash
set -euo pipefail

# 用法:
#   ./release.sh 1.2.15
#
# 脚本会自己跑 gradle 构建，改完源码（Java / Kotlin / C++）直接执行即可。
# 如果确认产物已是最新、想跳过构建，用: SKIP_BUILD=1 ./release.sh 1.2.15

VERSION="${1:-}"
if [ -z "${VERSION}" ]; then
  echo "用法: $0 <version>"
  exit 1
fi

# 固定坐标
GROUP_ID="io.github.coder-dongjiayi"
ARTIFACT_ID="mxlogger"
GPG_KEY="99ECB1C655BCEDC6"    # 你的 GPG 主 KeyID

# ===== 路径写死 =====
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="${PROJECT_DIR}/mxlogger"
GRADLEW="${PROJECT_DIR}/gradlew"
AAR_SRC="${SRC_DIR}/build/outputs/aar/mxlogger-DefaultCpp-release.aar"  # 固定 AAR 路径
JAVADOC_SRC="${SRC_DIR}/build/libs/mxlogger-javadoc.jar"                # javadocJar 任务产物

# ===== 构建 =====
# assembleDefaultCppRelease 会重新跑 CMake，C++ 改动也会被带进 .so
if [ "${SKIP_BUILD:-0}" = "1" ]; then
  echo "⏭  SKIP_BUILD=1，跳过 gradle 构建"
else
  echo "🔨 gradle 构建中（AAR + javadoc）..."
  export LANG="${LANG:-en_US.UTF-8}"
  "${GRADLEW}" -p "${PROJECT_DIR}" --console=plain \
    :mxlogger:assembleDefaultCppRelease \
    :mxlogger:javadocJar
  echo "✅ 构建完成"
fi

if [ ! -f "${AAR_SRC}" ]; then
  echo "❌ 未找到 AAR 文件: ${AAR_SRC}"
  exit 1
fi
echo "✅ 使用 AAR: ${AAR_SRC}"

# ===== 新鲜度检查 =====
# 只在跳过构建时才需要：正常路径下 gradle 已经保证了产物是最新的。
# 注意这里比的是 mtime，而 gradle 比的是内容哈希，两者会不一致——
# touch / git checkout / 无改动保存都会把源码 mtime 推新而 gradle 判定 UP-TO-DATE
# （不重写 AAR），此时下面会误报。真遇到就去掉 SKIP_BUILD 正常跑一次。
if [ "${SKIP_BUILD:-0}" = "1" ]; then
  STALE="$(find "${SRC_DIR}/src/main" -type f \
    \( -name '*.java' -o -name '*.kt' -o -name '*.cpp' -o -name '*.cc' -o -name '*.h' -o -name '*.hpp' \) \
    -newer "${AAR_SRC}" 2>/dev/null | head -5)"
  if [ -n "${STALE}" ]; then
    echo "❌ 以下源码比 AAR 新，产物可能不是最新的："
    echo "${STALE}"
    echo "   如果确认内容没变（touch / 切分支导致），去掉 SKIP_BUILD 重跑即可。"
    exit 1
  fi
fi

# ===== 输出目录 =====
OUTPUT_DIR="${PROJECT_DIR}/release/${VERSION}"
mkdir -p "${OUTPUT_DIR}"

AAR_FILE="${OUTPUT_DIR}/${ARTIFACT_ID}-${VERSION}.aar"
SRC_JAR_FILE="${OUTPUT_DIR}/${ARTIFACT_ID}-${VERSION}-sources.jar"
DOC_JAR_FILE="${OUTPUT_DIR}/${ARTIFACT_ID}-${VERSION}-javadoc.jar"
POM_FILE="${OUTPUT_DIR}/${ARTIFACT_ID}-${VERSION}.pom"

# 拷贝 AAR
cp -f "${AAR_SRC}" "${AAR_FILE}"
echo "✅ 拷贝 AAR -> ${AAR_FILE}"

# ===== 打包 sources.jar（含 Java/Kotlin 源）=====
echo "✅ 打包 sources.jar..."
rm -f "${SRC_JAR_FILE}"
if [ -d "${SRC_DIR}/src/main/java" ]; then
  jar cf "${SRC_JAR_FILE}" -C "${SRC_DIR}/src/main/java" .
fi
if [ -d "${SRC_DIR}/src/main/kotlin" ]; then
  if [ -f "${SRC_JAR_FILE}" ]; then
    jar uf "${SRC_JAR_FILE}" -C "${SRC_DIR}/src/main/kotlin" .
  else
    jar cf "${SRC_JAR_FILE}" -C "${SRC_DIR}/src/main/kotlin" .
  fi
fi
if [ ! -f "${SRC_JAR_FILE}" ]; then
  echo "⚠️ 未找到源码目录，sources.jar 将为空占位。"
  mkdir -p "${OUTPUT_DIR}/_empty_sources"
  echo "placeholder" > "${OUTPUT_DIR}/_empty_sources/placeholder.txt"
  jar cf "${SRC_JAR_FILE}" -C "${OUTPUT_DIR}/_empty_sources" .
  rm -rf "${OUTPUT_DIR}/_empty_sources"
fi

# ===== javadoc.jar（Maven Central 正式版强制要求）=====
if [ -f "${JAVADOC_SRC}" ]; then
  cp -f "${JAVADOC_SRC}" "${DOC_JAR_FILE}"
  echo "✅ 拷贝 javadoc.jar -> ${DOC_JAR_FILE}"
else
  echo "⚠️ 未找到 ${JAVADOC_SRC}，javadoc.jar 将为空占位。"
  mkdir -p "${OUTPUT_DIR}/_empty_javadoc"
  echo "placeholder" > "${OUTPUT_DIR}/_empty_javadoc/placeholder.txt"
  jar cf "${DOC_JAR_FILE}" -C "${OUTPUT_DIR}/_empty_javadoc" .
  rm -rf "${OUTPUT_DIR}/_empty_javadoc"
fi

# ===== 生成 pom.xml =====
cat > "${POM_FILE}" <<EOF
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <groupId>${GROUP_ID}</groupId>
  <artifactId>${ARTIFACT_ID}</artifactId>
  <version>${VERSION}</version>
  <packaging>aar</packaging>

  <name>${ARTIFACT_ID}</name>
  <description>MXLogger Android Library</description>
  <url>https://github.com/coder-dongjiayi/MXLogger</url>

  <licenses>
    <license>
      <name>The Apache Software License, Version 2.0</name>
      <url>http://www.apache.org/licenses/LICENSE-2.0.txt</url>
    </license>
  </licenses>

  <scm>
    <url>https://github.com/coder-dongjiayi/MXLogger</url>
    <connection>scm:git:git://github.com/coder-dongjiayi/MXLogger.git</connection>
    <developerConnection>scm:git:ssh://github.com/coder-dongjiayi/MXLogger.git</developerConnection>
  </scm>

  <developers>
    <developer>
      <id>dongjiayi</id>
      <name>dong jiayi</name>
      <email>mr.dongjiayi@gmail.com</email>
    </developer>
  </developers>
</project>
EOF
echo "✅ 生成 POM -> ${POM_FILE}"

# ===== 签名 & 摘要 =====
export GPG_TTY=$(tty || true)

sign_and_hash() {
  local FILE="$1"
  echo "➡️ 处理: $(basename "$FILE")"

  gpg --batch --yes --local-user "${GPG_KEY}" --armor --detach-sign --digest-algo SHA256 "${FILE}"

  for target in "${FILE}" "${FILE}.asc"; do
    openssl dgst -md5    -r "${target}" | awk '{print $1}' > "${target}.md5"
    openssl dgst -sha1   -r "${target}" | awk '{print $1}' > "${target}.sha1"
    openssl dgst -sha256 -r "${target}" | awk '{print $1}' > "${target}.sha256"
    openssl dgst -sha512 -r "${target}" | awk '{print $1}' > "${target}.sha512"
  done
}

for f in "${AAR_FILE}" "${SRC_JAR_FILE}" "${DOC_JAR_FILE}" "${POM_FILE}"; do
  sign_and_hash "${f}"
done

# ===== 组装 staging 并打包 ZIP 到 release 目录 =====
STAGING_ROOT="${PROJECT_DIR}/staging"
STAGING_DIR="${STAGING_ROOT}/${GROUP_ID//.//}/${ARTIFACT_ID}/${VERSION}"
rm -rf "${STAGING_ROOT}"
mkdir -p "${STAGING_DIR}"

# 拷贝文件到 staging
cp -f "${OUTPUT_DIR}/${ARTIFACT_ID}-${VERSION}.aar"*          "${STAGING_DIR}/"
cp -f "${OUTPUT_DIR}/${ARTIFACT_ID}-${VERSION}-sources.jar"*  "${STAGING_DIR}/"
cp -f "${OUTPUT_DIR}/${ARTIFACT_ID}-${VERSION}-javadoc.jar"*  "${STAGING_DIR}/"
cp -f "${OUTPUT_DIR}/${ARTIFACT_ID}-${VERSION}.pom"*          "${STAGING_DIR}/"

# 打包 staging 下所有文件为 ZIP 到 release 目录
ZIP_FILE="${PROJECT_DIR}/release/${VERSION}_mxlogger.zip"
rm -f "${ZIP_FILE}"
(
  cd "${STAGING_ROOT}"
  zip -r "${ZIP_FILE}" .
)
echo "📦 已打包 ZIP -> ${ZIP_FILE}"

# ===== 删除 staging 和 release 下临时子目录，只保留 ZIP =====
rm -rf "${STAGING_ROOT}" "${OUTPUT_DIR}"
echo "🧹 已删除临时目录，只保留 ZIP 文件"
