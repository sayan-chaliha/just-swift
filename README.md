# just-swift

## What is `just-swift`?

`just-swift` is a task library for Swift Package Manager, written in Swift, inspired by
[Microsoft Just](https://microsoft.github.io/just/).

## Why?

Swift Package Manager currently does not have support for automating build tasks.
Moreover, while there may be scattered tools available across the community, it
is hard to generate test and coverage reports that can be imported into CI systems.

`just-swift` sovles these problems.

## How?

### Setup a Command-Line Executable

The executable could be in a separate Swift package, or a target in your current project.

#### Add Dependency

```swift
...
dependencies: [
   ...
   .package(url: "https://github.com/sayan-chaliha/just-swift", branch: "main"),
   ...
],
...
```

#### Add Target

```swift
 ...
targets: [
   ...
   .executableTarget(name: "BuildTool", dependencies: [.product(name: "JustSwift", from: "just-swift")]),
   ...
],
...
```

#### Add Sources

Create a `Sources/BuildTool/BuildTool.swift` file with:

```swift
import JustSwift

@main
struct BuildTool {
    static func main() async throws {
        let just = try await Just.configure { _ in
            task("build", help: "Build the Swift package", SwiftBuildTask())
            task("clean", help: "Clean build output", SwiftCleanTask())
            task("test", help: "Run unit tests", SwiftTestTask())
            task("rebuild", help: "Clean and build Swift package", .series("clean", "build"))
            task("lint", help: "Run lint on sources", SwiftLintTask())
            task("format", help: "Run format on sources", SwiftFormatTask())
            task("check", help: "Format, lint and test code", .series("format", "lint", "rebuild", "test"))
            task("versions", help: "Prints computed current and next versions of the project", VersionTask())
            task("git:pre-commit", help: "Run pre-commit validation", "check")
            task("git:commit-msg", help: "Lint commit message", GitCommitMessageLint())

            try Git.install(hook: .preCommit, task: "git:pre-commit")
            try Git.install(hook: .commitMsg, task: "git:commit-msg")
        }

        try await just.execute()
    }
}
```

#### Run your Build Tool

`swift run -- BuildTool --help`

```
USAGE
  BuildTool <command> [--verbose] [--root-directory=<root-directory>]

OPTIONS
  -v, --verbose           Enable verbose logging (default: false)
  -r, --root-directory=<root-directory>
                          Path to root directory of Swift Package
  -h, --help              Show help information

COMMANDS
  build                   Build the Swift package
  clean                   Clean build output
  test                    Run unit tests
  lint                    Run lint on sources
  format                  Run format on sources
  versions                Prints computed current and next versions of the project
  git:commit-msg          Lint commit message
  rebuild                 Clean and build Swift package
  check                   Format, lint and test code
  git:pre-commit          Run pre-commit validation
```

`swift run -- BuildTool test --help`

```
USAGE
  BuildTool test [--test-report-format=<test-report-format>] [--test-report-path=<test-report-path>] [--enable-test-parallel|--disable-test-parallel]
  [--enable-coverage|--disable-coverage] [--coverage-threshold=<coverage-threshold>] [--coverage-report-format=<coverage-report-format>]
  [--coverage-report-ignore-pattern=<coverage-report-ignore-pattern>] [--coverage-report-path=<coverage-report-path>]

DESCRIPTION
  Run unit tests

OPTIONS
  --test-report-format=<test-report-format>
                          Format of the test report (choices: junit) (default: junit)
  --test-report-path=<test-report-path>
                          Relative or absolute path to write test reports to (default: .build/test.xml)
  --enable-coverage|--disable-coverage
                          Enable code coverage reporting (default: false)
  --coverage-threshold=<coverage-threshold>
                          Line coverage threshold; if coverage falls below this value the task will fail (default: 85.0)
  --coverage-report-format=<coverage-report-format>
                          Format of the coverage report (choices: cobertura) (default: cobertura)
  --coverage-report-ignore-pattern=<coverage-report-ignore-pattern>
                          File/directory patterns to ignore (default: <none>)
  --coverage-report-path=<coverage-report-path>
                          Relative or absolute path to write code coverage reports to (default: .build/coverage.xml)
```

### Defining Tasks

#### Simple Tasks

```swift
task("task-name", help: "task help message, displayed in `BuildTool --help`") { argv in
    // Do some work!
}
```

#### Tasks via `TaskProvider`

```swift
struct SomeTask: TaskProvider {
    public func callAsFunction(_ argumentBuilder: inout ArgumentBuilder) -> TaskFunction {
        argumentBuilder
            .option(
                "some-option",
                type: String.self,
                help: "Some option",
                default: "default")
            .flag(
                "flag",
                inversionPrefix: .no, // .no for --flag, and --no-flag; .enableDisable for --enable-flag, and --disable-flag; .none for --flag.
                help: "Enables/disables flag",
                default: true
            )

        return { argv in
            let someOption: String? = argv["some-option"]
            let flag: Bool? = argv.flag

            // ...
        }
    }
}

// in Just.configure { ... }
task("some-task", help: "some task help", SomeTask())
```

#### Tasks via Composition

```swift
task("task-a", help: "...") {
    // ...
}

task("task-b", help: "...") {
    // ...
}

task("task-c", help: "...") {
    // ...
}

task("all-tasks", help: "...", .series("task-a", .parallel("task-b", "task-c")))
```

### Authors

- Sayan Chaliha

### License

```
 Copyright (c) 2021 Microsoft Corporation.
 All Rights Reserved

 MIT License
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
```
