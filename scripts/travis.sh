#!/usr/bin/env bash
set -evx

setupCoursierBinDir() {
  mkdir -p bin
  cp coursier bin/
  export PATH="$(pwd)/bin:$PATH"
}

integrationTestsRequirements() {
  # Required for ~/.ivy2/local repo tests
  DUMMY_PROGUARD=1 sbt 'set version in ThisBuild := "0.1.2-publish-local"' scala212 coreJVM/publishLocal cli/publishLocal
}

isScalaJs() {
  [ "$SCALA_JS" = 1 ]
}

isScalaNative() {
  [ "$NATIVE" = 1 ]
}

bootstrap() {
  [ "$BOOTSTRAP" = 1 ]
}

jsCompile() {
  sbt scalaFromEnv js/compile js/test:compile coreJS/fastOptJS cacheJS/fastOptJS testsJS/test:fastOptJS js/test:fastOptJS
}

jvmCompile() {
  sbt scalaFromEnv jvm/compile jvm/test:compile
}

runJsTests() {
  sbt scalaFromEnv js/test
}

runJvmTests() {
  if [ "$(uname)" == "Darwin" ]; then
    IT="testsJVM/it:test" # don't run proxy-tests in particular
  else
    IT="jvm/it:test"
  fi

  ./scripts/with-redirect-server.sh \
    ./modules/tests/handmade-metadata/scripts/with-test-repo.sh \
    sbt scalaFromEnv jvm/test $IT
}

checkBinaryCompatibility() {
  sbt scalaFromEnv coreJVM/mimaReportBinaryIssues cacheJVM/mimaReportBinaryIssues
}

testBootstrap() {

  sbt scalaFromEnv "project cli" pack

  # nailgun

  modules/cli/target/pack/bin/coursier bootstrap \
    -o echo-ng \
    --standalone \
    io.get-coursier:echo:1.0.0 \
    com.facebook:nailgun-server:1.0.0 \
    -M com.facebook.nailgun.NGServer
  java -jar ./echo-ng &
  sleep 2
  local OUT="$(ng-nailgun coursier.echo.Echo foo)"
  if [ "$OUT" != foo ]; then
    echo "Error: unexpected output from the nailgun-based echo command." 1>&2
    exit 1
  fi

  # other

  modules/cli/target/pack/bin/coursier bootstrap -o cs-echo io.get-coursier:echo:1.0.1
  local OUT="$(./cs-echo foo)"
  if [ "$OUT" != foo ]; then
    echo "Error: unexpected output from bootstrapped echo command." 1>&2
    exit 1
  fi

  modules/cli/target/pack/bin/coursier bootstrap -o cs-echo-standalone io.get-coursier:echo:1.0.1 --standalone
  local OUT="$(./cs-echo-standalone foo)"
  if [ "$OUT" != foo ]; then
    echo "Error: unexpected output from bootstrapped standalone echo command." 1>&2
    exit 1
  fi

  modules/cli/target/pack/bin/coursier bootstrap -o cs-scalafmt-standalone org.scalameta:scalafmt-cli_2.12:2.0.0-RC4 --standalone
  # return code 0 is enough
  ./cs-scalafmt-standalone --help

  if echo "$OSTYPE" | grep -q darwin; then
    GREP="ggrep"
  else
    GREP="grep"
  fi

  LOCAL_VERSION="0.1.0-test-SNAPSHOT"

  sbt "set version in ThisBuild := \"$LOCAL_VERSION\"" scalaFromEnv cli/publishLocal
  VERSION="$LOCAL_VERSION" OUTPUT="coursier-test" scripts/generate-launcher.sh -r ivy2Local
  ./coursier-test bootstrap -o cs-echo-launcher io.get-coursier:echo:1.0.0
  if [ "$(./cs-echo-launcher foo)" != foo ]; then
    echo "Error: unexpected output from bootstrapped echo command (generated by proguarded launcher)." 1>&2
    exit 1
  fi

  if [ "$(./cs-echo-launcher -J-Dother=thing foo -J-Dfoo=baz)" != foo ]; then
    echo "Error: unexpected output from bootstrapped echo command (generated by proguarded launcher)." 1>&2
    exit 1
  fi

  if [ "$(./cs-echo-launcher "-n foo")" != "-n foo" ]; then
    echo "Error: unexpected output from bootstrapped echo command (generated by proguarded launcher)." 1>&2
    exit 1
  fi

  # run via the launcher rather than via the sbt-pack scripts, because the latter interprets -Dfoo=baz itself
  # rather than passing it to coursier since https://github.com/xerial/sbt-pack/pull/118
  ./coursier-test bootstrap -o cs-props -D other=thing -J -Dfoo=baz io.get-coursier:props:1.0.2
  local OUT="$(./cs-props foo)"
  if [ "$OUT" != baz ]; then
    echo -e "Error: unexpected output from bootstrapped props command.\n$OUT" 1>&2
    exit 1
  fi
  local OUT="$(./cs-props other)"
  if [ "$OUT" != thing ]; then
    echo -e "Error: unexpected output from bootstrapped props command.\n$OUT" 1>&2
    exit 1
  fi

  if [ "$(./cs-props -J-Dhappy=days happy)" != days ]; then
    echo "Error: unexpected output from bootstrapped props command." 1>&2
    exit 1
  fi

  if [ "$(JAVA_OPTS=-Dhappy=days ./cs-props happy)" != days ]; then
    echo "Error: unexpected output from bootstrapped props command." 1>&2
    exit 1
  fi

  if [ "$(JAVA_OPTS="-Dhappy=days -Dfoo=other" ./cs-props happy)" != days ]; then
    echo "Error: unexpected output from bootstrapped props command." 1>&2
    exit 1
  fi

  # assembly tests
  ./coursier-test bootstrap -a -o cs-props-assembly -D other=thing -J -Dfoo=baz io.get-coursier:props:1.0.2
  local OUT="$(./cs-props-assembly foo)"
  if [ "$OUT" != baz ]; then
    echo -e "Error: unexpected output from assembly props command.\n$OUT" 1>&2
    exit 1
  fi
  local OUT="$(./cs-props-assembly other)"
  if [ "$OUT" != thing ]; then
    echo -e "Error: unexpected output from assembly props command.\n$OUT" 1>&2
    exit 1
  fi
}

testNativeBootstrap() {
  sbt scalaFromEnv cli/pack
  modules/cli/target/pack/bin/coursier bootstrap -S -o native-echo io.get-coursier:echo_native0.3_2.11:1.0.1
  if [ "$(./native-echo -n foo a)" != "foo a" ]; then
    echo "Error: unexpected output from native test bootstrap." 1>&2
    exit 1
  fi
}

setupCoursierBinDir

if isScalaJs; then
  jsCompile
  runJsTests
elif isScalaNative; then
  testNativeBootstrap
elif bootstrap; then
  testBootstrap
else
  integrationTestsRequirements
  jvmCompile

  runJvmTests

  checkBinaryCompatibility
fi

