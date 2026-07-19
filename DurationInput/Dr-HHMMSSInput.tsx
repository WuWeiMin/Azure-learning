import * as React from "react";
import { Stack, TextField, Text, ITextFieldStyles } from "@fluentui/react";

export interface IHHMMSSInputProps {
    /** 字段当前值, 期望 "HH:MM:SS" 或空 */
    value: string;
    disabled: boolean;
    /** 组合出完整值(或null=清空)时回调 */
    onChange: (value: string | null) => void;
}

/** 把 "HH:MM:SS" 拆成三段, 非法/空 → 三个空串 */
function parse(v: string): [string, string, string] {
    const m = /^(\d{1,2}):([0-5]?\d):([0-5]?\d)$/.exec((v || "").trim());
    return m ? [m[1], m[2], m[3]] : ["", "", ""];
}

const pad = (s: string) => (s === "" ? "" : s.padStart(2, "0"));

/** 单框输入过滤: 只留数字, 最多2位, 分/秒钳制到59 */
function clean(raw: string, clamp59: boolean): string {
    let s = raw.replace(/\D/g, "").slice(0, 2);
    if (clamp59 && s.length > 0 && parseInt(s, 10) > 59) s = "59";
    return s;
}

const boxStyles: Partial<ITextFieldStyles> = {
    root: { width: 44 },
    field: { textAlign: "center" },
};

export const HHMMSSInput: React.FC<IHHMMSSInputProps> = (props) => {
    const [h, setH] = React.useState<string>("");
    const [m, setM] = React.useState<string>("");
    const [s, setS] = React.useState<string>("");
    // 记录最近一次向外发出的值, 用于区分"外部更新"和"自己发出的回流"
    const lastEmitted = React.useRef<string | null>(null);

    const mRef = React.useRef<HTMLInputElement>(null);
    const sRef = React.useRef<HTMLInputElement>(null);

    // 外部值变化(表单加载/其他脚本改值)时同步到三框
    React.useEffect(() => {
        const incoming = (props.value || "").trim();
        if (incoming === (lastEmitted.current ?? "")) return; // 自己发出的回流, 忽略
        const [ph, pm, ps] = parse(incoming);
        setH(ph); setM(pm); setS(ps);
        lastEmitted.current = incoming === "" ? null : incoming;
    }, [props.value]);

    /** 任一框变化后组合值发给PCF: 全空→null, 否则空框按"00"补齐 */
    const emit = (nh: string, nm: string, ns: string) => {
        let out: string | null;
        if (nh === "" && nm === "" && ns === "") {
            out = null;
        } else {
            out = `${pad(nh) || "00"}:${pad(nm) || "00"}:${pad(ns) || "00"}`;
        }
        lastEmitted.current = out;
        props.onChange(out);
    };

    const onBox =
        (setter: (v: string) => void, which: "h" | "m" | "s") =>
        (_: unknown, raw?: string) => {
            const v = clean(raw ?? "", which !== "h");
            setter(v);
            const nh = which === "h" ? v : h;
            const nm = which === "m" ? v : m;
            const ns = which === "s" ? v : s;
            emit(nh, nm, ns);
            // 敲满2位自动跳下一框
            if (v.length === 2) {
                if (which === "h") mRef.current?.focus();
                if (which === "m") sRef.current?.focus();
            }
        };

    // 失焦时把显示值补零(存储值在emit时已补, 这里只为显示整齐)
    const padOnBlur = (val: string, setter: (v: string) => void) => () => {
        if (val !== "") setter(pad(val));
    };

    const sep = <Text styles={{ root: { alignSelf: "center", fontWeight: 600 } }}>:</Text>;

    return (
        <Stack horizontal tokens={{ childrenGap: 4 }} verticalAlign="center">
            <TextField
                ariaLabel="小时"
                placeholder="HH"
                value={h}
                disabled={props.disabled}
                onChange={onBox(setH, "h")}
                onBlur={padOnBlur(h, setH)}
                styles={boxStyles}
                inputMode="numeric"
            />
            {sep}
            <TextField
                ariaLabel="分钟"
                placeholder="MM"
                value={m}
                disabled={props.disabled}
                onChange={onBox(setM, "m")}
                onBlur={padOnBlur(m, setM)}
                styles={boxStyles}
                inputMode="numeric"
                componentRef={(r) => { (mRef as React.MutableRefObject<HTMLInputElement | null>).current = (r as unknown as { _textElement?: { current: HTMLInputElement } })?._textElement?.current ?? null; }}
            />
            {sep}
            <TextField
                ariaLabel="秒"
                placeholder="SS"
                value={s}
                disabled={props.disabled}
                onChange={onBox(setS, "s")}
                onBlur={padOnBlur(s, setS)}
                styles={boxStyles}
                inputMode="numeric"
                componentRef={(r) => { (sRef as React.MutableRefObject<HTMLInputElement | null>).current = (r as unknown as { _textElement?: { current: HTMLInputElement } })?._textElement?.current ?? null; }}
            />
        </Stack>
    );
};
