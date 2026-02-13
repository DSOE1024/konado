# Code Contribution Guide

## Ways to Contribute

Whether it's documentation, code, or other content, you can contribute through the following methods:

- **Pull Request**: Submit code to the repository, which will be merged into the main branch after code review
- **Issue**: Submit issues or suggestions, which will be discussed to determine whether to implement and assigned to developers


## Code Contribution Process

Before submitting code, please ensure that you have completed the global configuration of Git locally. The local Git commit email and username **need to be consistent with the email and username registered on the platform**, otherwise incorrect commit records will be generated and you will not be included in the contributor list.

If you are not sure whether your email and username are correct, please check your Git configuration in the terminal:

```shell
git config --global user.name
git config --global user.email
```

If you need to modify, you can use the following commands, replacing "Your Name" and "your.email@example.com" with your username and email respectively:

```shell
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

After completing the configuration, it is recommended to restart the terminal to ensure that the configuration takes effect.

1. **Fork the project**: Click Fork in the upper right corner to your own repository  
2. **Create a branch**: `git checkout -b feature/your-feature`  
3. **Commit changes**: `git commit -m "feat: describe your changes"`  
4. **Push the branch**: `git push origin feature/your-feature`  
5. **Submit PR**: Create a Pull Request

The contributed code will undergo code review and be merged into the main branch after approval.

## GDScript Programming Specification Reference

This project follows the code specifications in the [GDScript Writing Style Guide](https://docs.godotengine.org/en/4.x/tutorials/scripting/gdscript/gdscript_styleguide.html) from the official Godot documentation. Here are some reference specifications:

### Format Specifications
- **Indentation**: Use tabs instead of spaces, one tab per level of indentation
- **Line length**: Keep within 100 characters, recommended under 80 characters to avoid affecting readability
- **Line breaks**: Use LF line breaks, keep line breaks at the end of files to avoid Git conflicts
- **Encoding**: UTF-8 without BOM to avoid garbled characters

Generally, using Godot's default script editor or VSCode can automatically meet these format specifications. If using other editors, please pay attention to these specifications.

### Naming Conventions
| Element Type | Naming Style | Example |
|---------|---------|------|
| File names | snake_case | `player_controller.gd` |
| Class names | PascalCase | `class_name PlayerController` |
| Functions/variables | snake_case | `func move_player()` |
| Signals | snake_case (past tense) | `signal door_opened` |
| Constants | CONSTANT_CASE | `const MAX_HEALTH = 100` |
| Enum names | PascalCase | `enum GameState` |
| Enum values | CONSTANT_CASE | `IDLE, RUNNING, JUMPING` |

Only English naming is allowed in scripts, other languages are not allowed to avoid problems.

### Comment Specifications

- **Class comments**: Each class needs comments at the top, describing the class's functionality and usage methods. This comment will be automatically generated into the documentation, so please be as detailed as possible
- **Function comments**: Each public function needs comments at the top, describing the function's functionality, parameters, and return values. If it's a private function or an internal utility function, comments can be omitted
- **Variable comments**: It is recommended to add comments to necessary variables, especially those with specific meanings or purposes
- **Signal comments**: Each signal needs comments at the top, describing the signal's purpose and parameters
- **TODO comments**: If you need to add todo items, please use `TODO` comments and describe the content and priority of the todo items


## Commit Specifications

For an open-source project, the initial learning cost and adaptation process of commit messages do require some effort, but the long-term returns it brings are huge. "Strict" information specifications can save time for understanding and communication between developers, and also provide convenience for the generation of change logs (CHANGELOG), making the generation of change logs more standardized.


### Commit Messages

This project references the Conventional Commits 1.0.0 specification, with the following specific format:

```
<type>(<scope>): <subject>
```

Including three fields: `type` (required), `scope` (optional), and `subject` (required).

**`type` (type)** is used to indicate the category of the commit, please use one of the following identifiers:

| Type         | Description                                     |
| :----------- | :--------------------------------------- |
| **feat**     | New feature                        |
| **fix**      | Fix bug                                |
| **docs**     | Modify documentation               |
| **test**     | Add tests or modify existing tests                   |
| **ci**       | Changes to CI configuration files and scripts               |

**`scope` (scope)** is used to indicate the scope affected by the commit, depending on the project. For example, it can be a module, component, file, etc.
*   `feat(something): ...`
*   `fix(ui): ...`
*   `docs(readme): ...`
*   If the scope is wide, it can be omitted or use (*).

**`subject` (subject)** is a short description of the purpose of this commit.

Examples are as follows:

```
feat(xxx): Add replay functionality
fix: Fix the issue where the replay speed is too fast causing the program to crash
docs(readme): Update readme
```

### Pull Request

PR (Pull Request) is used to submit your code to the main branch of the main repository. Before submitting a PR, please ensure that your code meets the following specifications:

1. Code format specification, conforming to the project's code style.
2. Commit message specification, conforming to Git Commit message specifications.
3. The submitted code has been tested and has no known issues.

If the above conditions are basically met, you can start submitting a PR.

### PR Submission Specifications

PR information needs to include the following content:

1. **Title**: Concisely and clearly describe the content of the PR, you can use Git Commit messages.
2. **Description**: Detailed description of the PR content, including implementation function description, implementation method, scope of impact, etc.
3. **Issue association**: If the PR is a fix for certain issues, please add the issue links to the PR information.

::: tip Other suggestions
1. To save the maintainers' time and energy, the PR description should be as detailed as possible.  
2. Except for simple bug fixes or text changes, all PRs need to have a "small essay"-like PR body, preferably with every detail.
3. Sometimes the commit content in the PR needs to be modified, please pay attention to the discussions in the PR comment section at any time.
4. Not all PRs will be merged, we apologize in advance for this.
:::

## Code Review

### Review Process

After submitting a PR, the project maintainers will review the code. During the review process, maintainers may provide some improvement suggestions, including but not limited to code style, performance optimization, security improvements, etc. Please carefully read and follow the suggestions provided by the maintainers, and make modifications according to the suggestions.

### Review Specifications

During the code review process, project maintainers will follow the following specifications:

1. **Code style**: Ensure that the code style complies with the project's code style guide.
2. **Performance optimization**: If there are serious performance issues in the code, please provide performance optimization solutions.
3. **Documentation updates**: If code modifications will affect documentation, please update the corresponding documentation.

::: tip Seeking help

In most cases, project maintainers will assist you in solving problems encountered during the code review process, ensuring that your code can be smoothly merged into the main branch. If you need help, please pay attention to the discussions in the PR comment section at any time.

:::

## Applying to Become a Maintainer

After making certain PR contributions to the project, you will be eligible to apply to become a maintainer. If you wish to become a maintainer, please send an email application following these steps:

1. Prepare personal Git account information, including username and email, which will be used to verify your contribution records and send invitation emails later.

2. Prepare project contribution information, including but not limited to links to previously submitted and merged PRs, number of discussions participated in, number of issues reported, etc.

3. Send an email to `konadoproject@163.com` with the subject "Application to become a Konado maintainer", and include the above information in the email content.

4. If you wish, you can attach your personal profile in the email, including your interests, skills, and experience in participating in open-source projects, so that we can better understand you.


The project maintainer team will reply to your application as soon as possible, and after confirming your contribution records, send an invitation email to your email address. Please follow the instructions in the email to complete the confirmation of maintainer identity and the setting of repository permissions.

We hope you can become a member of our Konado project and contribute to the open-source community together!
