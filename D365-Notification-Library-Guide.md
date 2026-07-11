# D365 表单交互工具库 — 从零搭建指南

## 项目目标

封装 `Xrm.Navigation`、`formContext.ui`、`Xrm.App` 等表单交互 API，配合统一错误码体系，
编译成单个 JS 文件，手动上传到 D365 Solution 作为 Web Resource，供所有表单脚本调用。

**最终产物结构：**
```
d365-notification-lib/
├── src/
│   ├── ErrorCodes.ts          ← 错误码 + 双语文案字典
│   └── NotificationHelper.ts  ← 核心交互封装
├── dist/
│   └── ripple.notifications.js  ← 编译产物，上传到D365的就是这个文件
├── package.json
├── tsconfig.json
└── README.md
```

---

## Step 0：环境检查

先确认版本，终端里执行：

```bash
node -v
npm -v
```

- Node.js 建议 `v18` 或以上
- npm 建议 `9.x` 以上

如果版本太旧（比如 Node < 16），先升级 Node 再继续。执行完把结果记一下，
后面装依赖如果报兼容性错误，大概率跟这个有关。

---

## Step 1：初始化项目

```bash
mkdir d365-notification-lib
cd d365-notification-lib
npm init -y
npm install --save-dev typescript @types/xrm
```

- `typescript`：编译器
- `@types/xrm`：D365 Client API 的类型定义，装完你写代码时会有智能提示，
  比如 `formContext.ui.` 打出来能看到所有方法

创建源码目录：
```bash
mkdir src
mkdir dist
```

---

## Step 2：配置 `tsconfig.json`

在项目根目录创建 `tsconfig.json`：

```json
{
  "compilerOptions": {
    "target": "ES2015",
    "module": "none",
    "outFile": "./dist/ripple.notifications.js",
    "lib": ["ES2015", "DOM"],
    "types": ["xrm"],
    "strict": true,
    "removeComments": true,
    "sourceMap": false
  },
  "include": ["src/**/*.ts"]
}
```

**关键点说明：**
- `"module": "none"` + `"outFile"`：这两个配合起来，会把 `src` 下所有 `.ts` 文件
  按依赖顺序**打包成一个 JS 文件**，不需要 webpack。这是给 D365 Web Resource 用的最简单方式。
- 我们用 TypeScript **namespace**（不是 ES Module）来组织代码，这样编译出来的
  JS 文件可以直接当 `<script>` 引用，不需要额外的模块加载器。

---

## Step 3：编写错误码字典 `src/ErrorCodes.ts`

```typescript
namespace Ripple.Utils {

    export enum ErrorCode {
        REQUIRED_FIELD_MISSING = "ERR001",
        INVALID_FORMAT = "ERR002",
        DUPLICATE_RECORD = "ERR003",
        PLUGIN_EXCEPTION = "ERR004",
        PERMISSION_DENIED = "ERR005",
        SAVE_FAILED = "ERR006",
        UNKNOWN = "ERR999",
    }

    export const ErrorMessages: { [key in ErrorCode]: { zh: string; en: string } } = {
        [ErrorCode.REQUIRED_FIELD_MISSING]: {
            zh: "必填字段未填写，请检查后重试",
            en: "A required field is missing. Please check and try again.",
        },
        [ErrorCode.INVALID_FORMAT]: {
            zh: "字段格式不正确",
            en: "Invalid field format.",
        },
        [ErrorCode.DUPLICATE_RECORD]: {
            zh: "记录已存在，不能重复创建",
            en: "This record already exists.",
        },
        [ErrorCode.PLUGIN_EXCEPTION]: {
            zh: "后台处理出现异常，请联系管理员",
            en: "A server-side error occurred. Please contact your administrator.",
        },
        [ErrorCode.PERMISSION_DENIED]: {
            zh: "您没有权限执行此操作",
            en: "You do not have permission to perform this action.",
        },
        [ErrorCode.SAVE_FAILED]: {
            zh: "保存失败，请稍后重试",
            en: "Save failed. Please try again later.",
        },
        [ErrorCode.UNKNOWN]: {
            zh: "发生未知错误",
            en: "An unknown error occurred.",
        },
    };

    export class ErrorCodeHelper {
        /** 根据错误码取对应语言的文案 */
        static getMessage(code: ErrorCode, lang: "zh" | "en" = "zh"): string {
            const entry = ErrorMessages[code];
            return entry ? entry[lang] : `未知错误码: ${code}`;
        }

        /**
         * 从插件抛出的异常信息里解析错误码。
         * 约定：C# 插件抛异常时消息格式为 "[ERR004] 具体描述"
         */
        static parsePluginError(error: any): { code: ErrorCode; rawMessage: string } {
            const message: string = error?.message || String(error);
            const match = message.match(/^\[(\w+)\]\s*(.*)$/);
            if (match && Object.values(ErrorCode).includes(match[1] as ErrorCode)) {
                return { code: match[1] as ErrorCode, rawMessage: match[2] };
            }
            return { code: ErrorCode.UNKNOWN, rawMessage: message };
        }
    }
}
```

**约定说明：** 以后 C# 插件里抛异常，建议按 `"[ERR004] Something went wrong"`
这种格式写消息，前端就能自动识别错误码、翻译成用户可读文案，不用每次手动对错误文本做字符串判断。

---

## Step 4：编写核心封装 `src/NotificationHelper.ts`

```typescript
/// <reference path="./ErrorCodes.ts" />

namespace Ripple.Utils {

    export class NotificationHelper {
        private static formContext: Xrm.FormContext;
        private static currentLang: "zh" | "en" = "zh";

        /** 每个表单 onLoad 时调用一次，注入 formContext */
        static init(context: Xrm.FormContext, lang: "zh" | "en" = "zh") {
            this.formContext = context;
            this.currentLang = lang;
        }

        // ---------- 表单级通知 ----------

        static showFormMessage(
            message: string,
            level: "ERROR" | "WARNING" | "INFO" = "INFO",
            id?: string
        ): string {
            const noticeId = id || this.generateId();
            this.formContext.ui.setFormNotification(message, level, noticeId);
            return noticeId;
        }

        static clearFormMessage(id: string) {
            this.formContext.ui.clearFormNotification(id);
        }

        // ---------- 字段级通知 ----------

        static showFieldError(fieldName: string, message: string, id?: string): string {
            const noticeId = id || this.generateId();
            const control = this.formContext.getControl(fieldName) as Xrm.Controls.StringControl;
            if (control) {
                control.setNotification(message, noticeId);
            } else {
                console.warn(`[NotificationHelper] 找不到字段: ${fieldName}`);
            }
            return noticeId;
        }

        static clearFieldError(fieldName: string, id: string) {
            const control = this.formContext.getControl(fieldName) as Xrm.Controls.StringControl;
            if (control) {
                control.clearNotification(id);
            }
        }

        // ---------- 全局通知（顶部横幅） ----------

        static async showGlobalNotification(
            message: string,
            type: "ERROR" | "WARNING" | "SUCCESS" | "INFO" = "INFO"
        ): Promise<string> {
            const typeMap: { [k: string]: number } = { ERROR: 1, WARNING: 2, SUCCESS: 3, INFO: 4 };
            const id = await Xrm.App.addGlobalNotification({
                type: typeMap[type] as any,
                level: 1,
                message: message,
                showCloseButton: true,
            });
            return id;
        }

        static clearGlobalNotification(id: string) {
            Xrm.App.clearGlobalNotification(id);
        }

        // ---------- 对话框 ----------

        static async confirm(text: string, title: string = "确认"): Promise<boolean> {
            const result = await Xrm.Navigation.openConfirmDialog({ text, title });
            return result.confirmed;
        }

        static async alert(text: string, title: string = "提示"): Promise<void> {
            await Xrm.Navigation.openAlertDialog({ text, title });
        }

        // ---------- 错误码集成 ----------

        /** 直接用错误码显示表单通知，自动翻译文案 */
        static showErrorByCode(code: ErrorCode, level: "ERROR" | "WARNING" = "ERROR", id?: string): string {
            const message = ErrorCodeHelper.getMessage(code, this.currentLang);
            console.error(`[NotificationHelper] ${code}: ${message}`);
            return this.showFormMessage(message, level, id);
        }

        /** 捕获插件/WebApi抛出的异常，自动解析错误码并展示 */
        static async handlePluginError(error: any): Promise<void> {
            const { code, rawMessage } = ErrorCodeHelper.parsePluginError(error);
            const friendlyMessage = ErrorCodeHelper.getMessage(code, this.currentLang);
            console.error(`[NotificationHelper] 插件异常 ${code}:`, rawMessage);
            await this.alert(friendlyMessage, "操作失败");
        }

        // ---------- 工具方法 ----------

        private static generateId(): string {
            return "notice_" + Date.now() + "_" + Math.random().toString(36).substr(2, 9);
        }
    }
}
```

---

## Step 5：编译

回到项目根目录执行：

```bash
npx tsc
```

编译成功后，`dist/ripple.notifications.js` 就是最终文件。打开看一下，
应该能看到两个 `namespace` 合并后的内容都在一个文件里。

**常见报错排查：**
- 报 `Cannot find type definition file for 'xrm'` → 检查 `@types/xrm` 是否装成功，
  再检查 `tsconfig.json` 里 `"types": ["xrm"]` 有没有写对
- 报找不到 `Ripple` 命名空间 → 检查 `NotificationHelper.ts` 顶部的
  `/// <reference path="./ErrorCodes.ts" />` 有没有漏写，这行是控制编译顺序的

---

## Step 6：上传到 D365 Solution

1. 打开你的 Unmanaged Solution（比如截图里那个 `AIARipple...` 系列）
2. 左侧导航 → **Web Resources** → **New**
3. 填写：
   - **Name**: `ripple_/js/ripple.notifications.js`（按你们团队命名规范来）
   - **Display Name**: Ripple Notification Helper
   - **Type**: Script (JScript)
4. 点击 **Choose File**，上传 `dist/ripple.notifications.js`
5. **Save** → **Publish**

---

## Step 7：在表单中引用并测试

1. 打开目标实体的表单编辑器
2. **Form Properties** → **Form Libraries** → **Add** → 找到刚上传的
   `ripple_/js/ripple.notifications.js`
3. 在 `onLoad` 事件里绑定一个初始化函数（新建一个业务专用 JS 文件，比如 `equipment_form.js`）：

```javascript
function onFormLoad(executionContext) {
    var formContext = executionContext.getFormContext();
    Ripple.Utils.NotificationHelper.init(formContext, "zh");

    // 测试表单通知
    Ripple.Utils.NotificationHelper.showFormMessage("工具库加载成功", "INFO", "init_test");
}
```

4. 保存发布后打开记录表单，应该能看到顶部出现蓝色 "工具库加载成功" 的通知条

**在浏览器 Console 里单独测试（不改表单代码的情况下）：**

先按之前教你的方式切换到表单所在的 iframe，然后：

```javascript
Ripple.Utils.NotificationHelper.init(Xrm.Page);
Ripple.Utils.NotificationHelper.showErrorByCode(Ripple.Utils.ErrorCode.REQUIRED_FIELD_MISSING);
```

应该会看到表单顶部弹出红色错误条，文案是"必填字段未填写，请检查后重试"。

---

## 后续可选扩展方向（先不用做，记个 TODO）

- [ ] 把 `errorCode` 前缀约定同步给写 C# 插件的同事，统一异常消息格式
- [ ] 加个 `showFieldErrorByCode()`，跟 `showErrorByCode` 类似但作用在字段上
- [ ] 如果以后多个表单都要用，可以把 `init()` 的调用也封装成一个通用 `onLoad` 模板函数

---

## 检查清单（跑完每一步勾一下）

- [ ] Step 0：`node -v` / `npm -v` 版本确认
- [ ] Step 1：`npm init` + 依赖安装成功
- [ ] Step 2：`tsconfig.json` 创建完成
- [ ] Step 3：`ErrorCodes.ts` 写完
- [ ] Step 4：`NotificationHelper.ts` 写完
- [ ] Step 5：`npx tsc` 编译无报错，`dist` 下生成了文件
- [ ] Step 6：Web Resource 上传 + Publish 成功
- [ ] Step 7：表单里测试通知条显示正常
