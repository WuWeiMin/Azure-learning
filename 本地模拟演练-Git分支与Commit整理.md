# 本地模拟演练：Git 分支流程与 Commit 整理

本文档记录了一次完整的本地模拟操作，用于在没有真实远程仓库的情况下，验证《Git 分支与提交规范手册》中的工作流程——包括建立"伪远程"仓库、创建 develop 分支、feature 分支碎片化提交、以及用 `rebase -i` 整理成干净的 Conventional Commits。适合新人照着操作一遍，实际感受整个流程。

---

## 一、环境准备：用本地裸仓库模拟远程

真实场景中远程仓库是 Bitbucket/GitHub，本地练习时可以用 `git init --bare` 建一个本地"假远程"，这样 `origin/develop`、`fetch`、`push` 这些命令才有意义，跟以后接真实远程操作完全一致。

```bash
# 建立裸仓库，充当"远程仓库"
mkdir /c/git-lab/remote.git
cd /c/git-lab/remote.git
git init --bare
```

**验证是否建立成功：**

```bash
ls -la /c/git-lab/remote.git
```

应该能看到 `HEAD`、`config`、`objects/`、`refs/` 等文件/目录，这才是一个合法的 bare 仓库。

> ⚠️ **踩坑提醒**：Git Bash（MINGW64）里反斜杠 `\` 是转义字符，会把路径里的字母"吃掉"。例如 `c:\git-lab\remote.git` 实际会被解析成 `c:git-labremote.git` 这种乱码路径，导致后续 clone 报错 `does not appear to be a git repository`。**全程使用正斜杠**：`c:/git-lab/remote.git`。

---

## 二、clone 出工作仓库，建立 develop 分支

```bash
cd /c/git-lab
git clone c:/git-lab/remote.git workspace
cd workspace
```

> 💡 clone 一个空仓库时会提示 `warning: You appear to have cloned an empty repository.`，这是正常现象（因为 remote.git 刚建好，还没有任何提交），不是错误。

```bash
git checkout -b develop
echo "hello" > readme.md
git add .
git commit -m "chore: init develop"
git push origin develop
```

**验证：**

```bash
git branch -r
```

应该能看到 `origin/develop`，说明"远程"上已经有这个分支了。

---

## 三、切 feature 分支，模拟真实开发中的碎片化提交

真实开发一个新功能时，往往会有很多零散的中间提交（调试、改错字、临时保存），这里故意模拟这种情况：

```bash
git checkout -b feature/cr1024-test

echo "framework code" > fileA.txt
git add . && git commit -m "feat(api): addnew fremwork"   # 故意留一个拼写错误

echo "line1" >> fileA.txt
git add . && git commit -m "new line"

echo "line2" >> fileA.txt
git add . && git commit -m "add line"

echo "line3" >> fileA.txt
git add . && git commit -m "delete one line"

echo "line4" >> fileA.txt
git add . && git commit -m "addd bland line"
```

用 `git log --oneline` 查看，此时应该有 5 条杂乱的提交记录——这就是"commit 噪音"的样子。

---

## 四、配置 VS Code 作为 rebase 编辑器

```bash
git config --global core.editor "code --wait"
```

配置后，`git rebase -i` 等需要打开文本编辑器的 git 命令，会自动弹出 VS Code 标签页，比命令行里的 vim/nano 好操作很多。

> ⚠️ **注意范围**：这个配置只对**命令行执行的 git 命令**生效（比如在 VS Code 集成终端、Git Bash 里敲 `git rebase -i`）。如果用的是 Visual Studio 自带的图形化 Git 面板（Git Changes 窗口、切分支弹窗、冲突解决界面），走的是 VS 自己的内部实现，**不会**调用这个配置，两者互不影响。

---

## 五、交互式 rebase：整理成一条干净的 commit

```bash
git rebase -i origin/develop
```

VS Code 会弹出一个 `git-rebase-todo` 标签页，列出 5 个提交（从旧到新）：

```
pick 1aa88ca # feat(api): addnew fremwork
pick a0d9404 # new line
pick 5c83e1b # add line
pick f52fa85 # delete one line
pick 9e39a95 # addd bland line
```

**操作：** 保留第一行 `pick`，把第 2~5 行的 `pick` 改成 `squash`（简写 `s`）：

```
pick   1aa88ca # feat(api): addnew fremwork
squash a0d9404 # new line
squash 5c83e1b # add line
squash f52fa85 # delete one line
squash 9e39a95 # addd bland line
```

`Ctrl+S` 保存，`Ctrl+W` 关闭标签页。

---

## 六、整理合并后的 commit message

关闭 todo 列表后，会自动弹出第二个标签页 `COMMIT_EDITMSG`，列出 5 条原始提交信息供你整理：

```
# This is a combination of 5 commits.
# This is the 1st commit message:

feat(api): addnew fremwork

wip: 1223
fix typo
wip:sdsd

# This is the commit message #2:

new line
...
```

**操作：** 删掉除最终标题外的所有内容行（`#` 开头的注释行会被 Git 自动忽略，删不删不影响结果），只保留一条整理好的、符合 Conventional Commits 格式的 message：

```
feat(api): add new framework

支持基础路由与请求处理骨架，后续接口在此基础上扩展。
```

`Ctrl+S` 保存后，**必须确认标签页标题旁的圆点（●，表示未保存）变成叉号（X）**，再关闭标签页。

---

## 七、验证 rebase 结果

关闭后，终端应显示：

```
Successfully rebased and updated refs/heads/feature/cr1024-test.
```

用以下命令验证：

```bash
git log --oneline
```

此时应该**只剩 1 条**整理好的 commit（`feat(api): add new framework`），而不是原来的 5 条碎片记录——这就是"消除 commit 噪音"的最终效果。

---

## 八、推送与模拟 Squash Merge

```bash
git push origin feature/cr1024-test
```

真实场景中，PR 合并到 `release/*` 时是在 Bitbucket/GitHub 网页上点 "Squash and merge"，本地可以这样模拟：

```bash
git checkout develop
git pull
git checkout -b release/cr1024

git merge --squash feature/cr1024-test
git commit -m "feat(api): add new framework"

git push origin release/cr1024
```

`--squash` 就是本地版的 "Squash Merge"，效果与平台上点按钮一致。

---

## 完整命令速览

```bash
# 1. 建立伪远程
mkdir /c/git-lab/remote.git && cd /c/git-lab/remote.git
git init --bare

# 2. clone 并建 develop
cd /c/git-lab
git clone c:/git-lab/remote.git workspace
cd workspace
git checkout -b develop
echo "hello" > readme.md
git add . && git commit -m "chore: init develop"
git push origin develop

# 3. feature 分支模拟碎片提交
git checkout -b feature/cr1024-test
# ...多次 add/commit...

# 4. 配置 rebase 编辑器
git config --global core.editor "code --wait"

# 5. 整理提交历史
git rebase -i origin/develop
# 在 VS Code 中把 pick 改为 squash，整理 commit message

# 6. 验证
git log --oneline

# 7. 推送 & 模拟 squash merge
git push origin feature/cr1024-test
git checkout develop && git pull
git checkout -b release/cr1024
git merge --squash feature/cr1024-test
git commit -m "feat(api): add new framework"
git push origin release/cr1024
```

---

## 常见报错排查记录（本次演练中实际遇到的问题）

| 报错 | 原因 | 解决 |
|---|---|---|
| `fatal: invalid upstream 'origin/develop'` | 本地还没有 `origin/develop` 这个远程跟踪分支 | 先 `git fetch origin`，或确认远程仓库确实存在该分支 |
| `git: 'colone' is not a git command` | 命令拼写错误 | 改成 `git clone` |
| `cd workspace: No such file or directory` | 上一步 clone 因拼写错误没执行成功，目录未创建 | 先修正 clone 命令，成功后再 cd |
| `fatal: 'c:git-labremote.git' does not appear to be a git repository` | 反斜杠路径在 Git Bash 中被转义吞字符 | 全程使用正斜杠 `c:/git-lab/remote.git` |
| `not a git repository (or any of the parent directories): .git` | 上一步 clone 失败，目录下没有 `.git` | 清空目录（`rm -rf workspace`），重新用正确路径 clone |
| `warning: You appear to have cloned an empty repository.` | 远程仓库刚建好还没有提交 | 属于正常提示，非报错，可忽略 |
