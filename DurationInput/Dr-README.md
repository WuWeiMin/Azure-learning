# DurationInput PCF — 从零到表单的步骤

绑定字段: `demo_threshold` (单行文本, 存 "HH:MM:SS")
控件类型: virtual (React + Fluent UI 平台库)

## 1. 创建项目

```bash
mkdir DurationInput && cd DurationInput
pac pcf init --namespace AIA --name DurationInput --template field --framework react --run-npm-install
```

> `--framework react` 生成 virtual control 骨架并在 manifest 里写好平台库版本。
> 如果你的 pac 版本不认识 --framework 参数, 先 `pac install latest` 升级。
> --run-npm-install 会自动装依赖; 没加的话手动 `npm install`。

## 2. 替换文件

把本包三个文件覆盖到项目根目录 (与生成的同名文件同位置):

| 文件 | 说明 |
|---|---|
| `ControlManifest.Input.xml` | ⚠ 覆盖前先看生成版里 `<platform-library>` 两行的 version, 以生成版为准改回来 |
| `index.ts` | 控件入口 |
| `HHMMSSInput.tsx` | 新增文件, 三分框组件 |

## 3. 本地调试

```bash
npm run build        # 先构建一次, 生成 generated/ManifestTypes
npm start watch      # 打开 test harness
```

test harness 里:
- 左侧属性面板给 thresholdValue 填 `00:22:05` → 三框应显示 00/22/05
- 手输分钟 67 → 自动变 59; 敲满两位自动跳下一框
- 全部清空 → 输出应为 null

## 4. 部署 (你们自己的流程)

```bash
npm run build -- --buildMode production
```

产物在 `out/controls/DurationInput/`。按你们 TagPicker 控件同样的方式
放进 solution 工程打包导入 (bundle.js + ControlManifest.xml 等)。

## 5. 挂表单

导入发布后: 表单编辑器 → 选中 demo_threshold 字段 → 组件 → 添加
"Duration Input (HH:MM:SS)" → 勾选 Web / Phone / Tablet → 保存发布。

## 已知边界与后续可加

- HH 目前限 2 位 (00-99 小时)。要支持 3 位改 HHMMSSInput.tsx 里 clean() 的 slice(0,2)
- 空框在有任一输入时按 "00" 参与组合 (输 22 到 HH 即得 "22:00:00")
- 存储为文本 → 下游 N52 计算需解析, 建议封装 {ThresholdToSeconds} Snippet 复用
- 之前 web resource 的 OnSave 校验可保留作为非表单通道无关的双保险, 或移除
- v2 甜点: ↑↓ 键微调、粘贴 "00:22:05" 自动拆框、只读态渲染为纯文本
