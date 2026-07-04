import * as React from "react";
import { IInputs, IOutputs } from "./generated/ManifestTypes";
import { LookupControl, ILookupProps } from "./LookupControl";

export class ConfigurableLookup
    implements ComponentFramework.ReactControl<IInputs, IOutputs> {

    private notifyOutputChanged: () => void;
    private value: string | null = null;
    private display: string | null = null;
    private sourceKey: string | null = null;

    public init(
        _context: ComponentFramework.Context<IInputs>,
        notifyOutputChanged: () => void
    ): void {
        this.notifyOutputChanged = notifyOutputChanged;
    }

    public updateView(
        context: ComponentFramework.Context<IInputs>
    ): React.ReactElement {
        // 平台传入的值优先(外部 JS 改值、表单刷新等场景)
        this.value = context.parameters.boundValue.raw;
        this.display = context.parameters.boundDisplay?.raw ?? this.display;
        this.sourceKey = context.parameters.boundSourceKey?.raw ?? this.sourceKey;

        const props: ILookupProps = {
            sourcesJson: context.parameters.sourcesJson?.raw ?? null,
            sourcesVariableName: context.parameters.sourcesVariableName?.raw ?? null,
            allowedSources: context.parameters.allowedSources?.raw ?? null,
            defaultSourceKey: context.parameters.defaultSourceKey?.raw ?? undefined,
            value: this.value,
            display: this.display,
            sourceKey: this.sourceKey,
            disabled: context.mode.isControlDisabled,
            onChange: (value, display, sourceKey) => {
                this.value = value;
                this.display = display;
                this.sourceKey = sourceKey;
                this.notifyOutputChanged();
            }
        };
        return React.createElement(LookupControl, props);
    }

    public getOutputs(): IOutputs {
        return {
            boundValue: this.value ?? undefined,
            boundDisplay: this.display ?? undefined,
            boundSourceKey: this.sourceKey ?? undefined
        };
    }

    public destroy(): void { /* React 由平台卸载 */ }
}
