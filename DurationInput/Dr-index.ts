import { IInputs, IOutputs } from "./generated/ManifestTypes";
import * as React from "react";
import { HHMMSSInput, IHHMMSSInputProps } from "./HHMMSSInput";

export class DurationInput implements ComponentFramework.ReactControl<IInputs, IOutputs> {
    private notifyOutputChanged: () => void;
    private currentValue: string | null = null;

    /**
     * 控件初始化。virtual control 不需要自己操作 DOM 容器。
     */
    public init(
        context: ComponentFramework.Context<IInputs>,
        notifyOutputChanged: () => void
    ): void {
        this.notifyOutputChanged = notifyOutputChanged;
        this.currentValue = context.parameters.thresholdValue.raw ?? null;
    }

    /**
     * 每次数据/状态变化时框架调用, 返回 React 元素。
     */
    public updateView(context: ComponentFramework.Context<IInputs>): React.ReactElement {
        const props: IHHMMSSInputProps = {
            value: context.parameters.thresholdValue.raw ?? "",
            disabled: context.mode.isControlDisabled,
            onChange: (v: string | null) => {
                this.currentValue = v;
                this.notifyOutputChanged();   // 通知框架来读 getOutputs
            },
        };
        return React.createElement(HHMMSSInput, props);
    }

    /**
     * 框架收到 notifyOutputChanged 后调用, 把值写回绑定字段。
     * 返回 undefined 表示清空字段。
     */
    public getOutputs(): IOutputs {
        return { thresholdValue: this.currentValue ?? undefined };
    }

    public destroy(): void {
        // virtual control 由框架卸载 React 树, 无需清理
    }
}
