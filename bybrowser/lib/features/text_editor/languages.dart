import 'package:re_highlight/languages/bash.dart';
import 'package:re_highlight/languages/c.dart';
import 'package:re_highlight/languages/cpp.dart';
import 'package:re_highlight/languages/csharp.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/diff.dart';
import 'package:re_highlight/languages/dockerfile.dart';
import 'package:re_highlight/languages/go.dart';
import 'package:re_highlight/languages/gradle.dart';
import 'package:re_highlight/languages/ini.dart';
import 'package:re_highlight/languages/java.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/kotlin.dart';
import 'package:re_highlight/languages/makefile.dart';
import 'package:re_highlight/languages/markdown.dart';
import 'package:re_highlight/languages/php.dart';
import 'package:re_highlight/languages/powershell.dart';
import 'package:re_highlight/languages/properties.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/ruby.dart';
import 'package:re_highlight/languages/rust.dart';
import 'package:re_highlight/languages/scss.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/languages/typescript.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/re_highlight.dart';

/// Ánh xạ phần mở rộng file → ngôn ngữ highlight của re_highlight.
/// Trả về `null` nếu không có highlight (hiển thị text thuần).
({String id, Mode mode})? languageForExtension(String ext) {
  return switch (ext) {
    'json' => (id: 'json', mode: langJson),
    'xml' || 'html' || 'htm' || 'svg' || 'plist' => (id: 'xml', mode: langXml),
    'yaml' || 'yml' => (id: 'yaml', mode: langYaml),
    'md' || 'markdown' => (id: 'markdown', mode: langMarkdown),
    'dart' => (id: 'dart', mode: langDart),
    'js' || 'jsx' || 'mjs' => (id: 'javascript', mode: langJavascript),
    'ts' || 'tsx' => (id: 'typescript', mode: langTypescript),
    'py' => (id: 'python', mode: langPython),
    'java' => (id: 'java', mode: langJava),
    'kt' || 'kts' => (id: 'kotlin', mode: langKotlin),
    'c' || 'h' => (id: 'c', mode: langC),
    'cpp' || 'cc' || 'hpp' || 'cxx' => (id: 'cpp', mode: langCpp),
    'cs' => (id: 'csharp', mode: langCsharp),
    'go' => (id: 'go', mode: langGo),
    'rs' => (id: 'rust', mode: langRust),
    'rb' => (id: 'ruby', mode: langRuby),
    'php' => (id: 'php', mode: langPhp),
    'css' => (id: 'css', mode: langCss),
    'scss' => (id: 'scss', mode: langScss),
    'sql' => (id: 'sql', mode: langSql),
    'sh' || 'bash' || 'zsh' => (id: 'bash', mode: langBash),
    'ps1' => (id: 'powershell', mode: langPowershell),
    'ini' || 'cfg' || 'conf' || 'toml' => (id: 'ini', mode: langIni),
    'properties' || 'env' => (id: 'properties', mode: langProperties),
    'gradle' => (id: 'gradle', mode: langGradle),
    'dockerfile' => (id: 'dockerfile', mode: langDockerfile),
    'makefile' || 'mk' => (id: 'makefile', mode: langMakefile),
    'diff' || 'patch' => (id: 'diff', mode: langDiff),
    _ => null,
  };
}
