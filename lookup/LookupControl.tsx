import * as React from "react";
import {
    TagPicker, ITag, IBasePickerSuggestionsProps
} from "@fluentui/react/lib/Pickers";
import { Dropdown, IDropdownOption } from "@fluentui/react/lib/Dropdown";
import { Stack } from "@fluentui/react/lib/Stack";
import { Text } from "@fluentui/react/lib/Text";
import { Icon } from "@fluentui/react/lib/Icon";

/** 单个数据源的配置 */
interface SourceDef {
    key: string;              // 唯一标识,写入 boundSourceKey;有存量数据后禁止改名
    label: string;            // 切换器里的显示名,可随时改
    query: string;            // 搜索查询;server 模式用 {search} 占位符
    valueField: string;       // 返回值属性(支持点路径)
    displayField: string;     // 显示值属性(支持点路径)
    secondaryField?: string;  // 建议项第二行小字
    searchMode?: "server" | "client";  // 默认 server
    resolveQuery?: string;    // 可选:按返回值反查单条记录,{value} 占位,
                              // 用于回显时刷新显示值 / 检测引用悬空
}

interface ResultTag extends ITag {
    secondary?: string;
    sourceKey: string;
}

export interface ILookupProps {
    sourcesJson: string | null;
    sourcesVariableName: string | null;
    allowedSources: string | null;
    defaultSourceKey?: string;
    value: string | null;
    display: string | null;
    sourceKey: string | null;
    disabled: boolean;
    onChange: (value: string | null, display: string | null,
               sourceKey: string | null) => void;
}

// ---------- 工具函数 ----------

const getClientUrl = (): string => {
    const xrm = (window as any).Xrm ?? (parent as any)?.Xrm;
    return xrm?.Utility?.getGlobalContext?.()?.getClientUrl?.() ?? "";
};

/** 点路径取值:DisplayName.UserLocalizedLabel.Label */
const resolvePath = (obj: any, path: string): string => {
    const v = path.split(".").reduce((acc, k) => acc?.[k], obj);
    return v == null ? "" : String(v);
};

/** OData 字符串字面量转义:单引号翻倍,防注入/防 400 */
const escapeOData = (s: string) => s.replace(/'/g, "''");

class HttpError extends Error {
    constructor(public status: number) { super(`HTTP ${status}`); }
}

const fetchApi = async (relativeUrl: string): Promise<any> => {
    const res = await fetch(getClientUrl() + relativeUrl, {
        headers: {
            "Accept": "application/json",
            "OData-MaxVersion": "4.0",
            "OData-Version": "4.0"
        }
    });
    if (!res.ok) throw new HttpError(res.status);
    return res.json();
};

/** 环境变量读取,window 级 Promise 缓存去重:
 *  同一表单多个控件实例共享一次请求;失败则移出缓存以便重试 */
const getEnvVarJson = (schemaName: string): Promise<string> => {
    const w = window as any;
    w.__lucyLookupEnvCache ??= new Map<string, Promise<string>>();
    const cache: Map<string, Promise<string>> = w.__lucyLookupEnvCache;

    if (!cache.has(schemaName)) {
        const p = (async () => {
            const url = "/api/data/v9.2/environmentvariabledefinitions"
                + `?$select=defaultvalue&$filter=schemaname eq '${escapeOData(schemaName)}'`
                + "&$expand=environmentvariabledefinition_environmentvariablevalue($select=value)";
            const def = (await fetchApi(url)).value?.[0];
            if (!def) throw new Error(`环境变量 ${schemaName} 不存在`);
            return def.environmentvariabledefinition_environmentvariablevalue?.[0]?.value
                ?? def.defaultvalue ?? "[]";
        })();
        p.catch(() => cache.delete(schemaName));
        cache.set(schemaName, p);
    }
    return cache.get(schemaName)!;
};

// ---------- 组件 ----------

type RefState = "ok" | "missing" | null;

export const LookupControl: React.FC<ILookupProps> = (props) => {

    const [sources, setSources] = React.useState<SourceDef[]>([]);
    const [configError, setConfigError] = React.useState<string | null>(null);
    const [searchError, setSearchError] = React.useState<string | null>(null);
    const [refState, setRefState] = React.useState<RefState>(null);
    const [activeKey, setActiveKey] = React.useState<string>("");

    // client 模式的全量缓存
    const cacheRef = React.useRef<Map<string, ResultTag[]>>(new Map());

    const toTags = React.useCallback((records: any[], src: SourceDef): ResultTag[] =>
        records.map(r => ({
            key: resolvePath(r, src.valueField),
            name: resolvePath(r, src.displayField) || resolvePath(r, src.valueField),
            secondary: src.secondaryField ? resolvePath(r, src.secondaryField) : undefined,
            sourceKey: src.key
        })).filter(t => !!t.key), []);

    const getClientCache = React.useCallback(async (src: SourceDef): Promise<ResultTag[]> => {
        let cached = cacheRef.current.get(src.key);
        if (!cached) {
            cached = toTags((await fetchApi(src.query)).value ?? [], src)
                .sort((a, b) => a.name.localeCompare(b.name));
            cacheRef.current.set(src.key, cached);
        }
        return cached;
    }, [toTags]);

    // ----- 配置加载:内联 JSON 优先,否则读环境变量;应用 allowedSources 过滤 -----
    React.useEffect(() => {
        const load = async (): Promise<void> => {
            setConfigError(null);
            try {
                let json: string;
                if (props.sourcesJson?.trim()) {
                    json = props.sourcesJson;
                } else if (props.sourcesVariableName?.trim()) {
                    json = await getEnvVarJson(props.sourcesVariableName.trim());
                } else {
                    throw new Error("未配置数据源:sourcesJson 与 sourcesVariableName 至少填一项");
                }

                let parsed: SourceDef[];
                try { parsed = JSON.parse(json); }
                catch { throw new Error("数据源 JSON 解析失败,请检查格式"); }
                if (!Array.isArray(parsed) || parsed.length === 0) {
                    throw new Error("数据源配置为空数组");
                }

                const allowed = props.allowedSources?.split(",")
                    .map(s => s.trim()).filter(Boolean);
                const filtered = allowed?.length
                    ? parsed.filter(s => allowed.includes(s.key))
                    : parsed;
                if (filtered.length === 0) {
                    throw new Error("allowedSources 过滤后无可用数据源,请检查 key 是否匹配");
                }
                setSources(filtered);
            } catch (e) {
                setSources([]);
                setConfigError((e as Error).message);
            }
        };
        void load();
    }, [props.sourcesJson, props.sourcesVariableName, props.allowedSources]);

    // ----- 默认数据源初始化 -----
    React.useEffect(() => {
        if (sources.length && !sources.some(s => s.key === activeKey)) {
            setActiveKey(
                sources.some(s => s.key === props.defaultSourceKey)
                    ? props.defaultSourceKey!
                    : sources[0].key);
        }
    }, [sources]);

    // ----- 回显校验:刷新过期显示值 / 检测引用悬空 -----
    React.useEffect(() => {
        const validate = async (): Promise<void> => {
            setRefState(null);
            if (!props.value || !sources.length) return;

            const src = sources.find(s => s.key === props.sourceKey)
                ?? (sources.length === 1 ? sources[0] : undefined);
            if (!src) return; // 无法确定来源,跳过校验

            try {
                let fresh: string | null = null;
                let found = false;

                if (src.resolveQuery) {
                    // 服务端按值反查单条
                    const url = src.resolveQuery.replace(/\{value\}/g,
                        encodeURIComponent(escapeOData(props.value)));
                    const json = await fetchApi(url);
                    const rec = Array.isArray(json.value) ? json.value[0] : json;
                    if (rec) {
                        found = true;
                        fresh = resolvePath(rec, src.displayField) || null;
                    }
                } else if (src.searchMode === "client") {
                    // 客户端缓存中校验
                    const hit = (await getClientCache(src))
                        .find(t => String(t.key) === props.value);
                    if (hit) { found = true; fresh = hit.name; }
                } else {
                    return; // server 模式且未配 resolveQuery:不校验
                }

                if (!found) {
                    setRefState("missing");
                } else {
                    setRefState("ok");
                    if (fresh && fresh !== props.display) {
                        // 源头显示名已变化,刷新持久化的显示值
                        props.onChange(props.value, fresh, src.key);
                    }
                }
            } catch (e) {
                if (e instanceof HttpError && e.status === 404) {
                    setRefState("missing");
                }
                // 其他错误(网络/权限)不下悬空结论,保持沉默
            }
        };
        void validate();
    }, [sources, props.value, props.sourceKey]);

    // ----- 搜索 -----
    const activeSource = sources.find(s => s.key === activeKey);

    const resolveSuggestions = React.useCallback(
        async (filter: string): Promise<ITag[]> => {
            const src = activeSource;
            if (!src) return [];
            try {
                let result: ITag[];
                if (src.searchMode === "client") {
                    const f = filter.toLowerCase().trim();
                    result = (await getClientCache(src)).filter(t => !f
                        || t.name.toLowerCase().includes(f)
                        || String(t.key).toLowerCase().includes(f)
                    ).slice(0, 25);
                } else {
                    const url = src.query.replace(/\{search\}/g,
                        encodeURIComponent(escapeOData(filter)));
                    result = toTags((await fetchApi(url)).value ?? [], src);
                }
                setSearchError(null);
                return result;
            } catch (e) {
                // 区分"没搜到"和"出错了",错误呈现给用户便于排查
                setSearchError(e instanceof HttpError
                    ? `${e.message}(请检查该数据源的 query 配置)`
                    : (e as Error).message);
                return [];
            }
        }, [activeSource, getClientCache, toTags]);

    const onEmptyFocus = React.useCallback(
        (): Promise<ITag[]> => resolveSuggestions(""), [resolveSuggestions]);

    // ----- 渲染 -----
    const renderSuggestion = (tag: ITag): JSX.Element => {
        const t = tag as ResultTag;
        return (
            <Stack tokens={{ childrenGap: 2 }}
                   styles={{ root: { padding: "6px 10px", textAlign: "left" } }}>
                <Text variant="medium">{t.name}</Text>
                {t.secondary &&
                    <Text variant="small" styles={{ root: { color: "#605e5c" } }}>
                        {t.secondary}
                    </Text>}
            </Stack>
        );
    };

    const suggestionsProps: IBasePickerSuggestionsProps = {
        suggestionsHeaderText: activeSource?.label ?? "",
        noResultsFoundText: searchError ? `查询出错:${searchError}` : "未找到记录",
        loadingText: "正在搜索...",
        resultsMaximumNumber: 25
    };

    const selected: ITag[] = props.value
        ? [{ key: props.value, name: props.display ?? props.value }]
        : [];

    const sourceOptions: IDropdownOption[] =
        sources.map(s => ({ key: s.key, text: s.label }));

    // 配置层错误:直接呈现,不渲染残废的控件
    if (configError) {
        return (
            <Stack horizontal verticalAlign="center" tokens={{ childrenGap: 6 }}
                   styles={{ root: { padding: "6px 8px" } }}>
                <Icon iconName="ErrorBadge" styles={{ root: { color: "#a4262c" } }} />
                <Text variant="small" styles={{ root: { color: "#a4262c" } }}>
                    数据源配置错误:{configError}
                </Text>
            </Stack>
        );
    }

    return (
        <Stack tokens={{ childrenGap: 4 }} styles={{ root: { width: "100%" } }}>
            <Stack horizontal tokens={{ childrenGap: 4 }}>
                {sources.length > 1 &&
                    <Dropdown
                        options={sourceOptions}
                        selectedKey={activeKey}
                        disabled={props.disabled}
                        onChange={(_e, opt) => opt && setActiveKey(String(opt.key))}
                        styles={{ root: { minWidth: 110 } }}
                    />}
                <Stack.Item grow>
                    <TagPicker
                        itemLimit={1}
                        disabled={props.disabled}
                        selectedItems={selected}
                        onResolveSuggestions={resolveSuggestions}
                        onEmptyResolveSuggestions={onEmptyFocus}
                        onRenderSuggestionsItem={renderSuggestion}
                        pickerSuggestionsProps={suggestionsProps}
                        resolveDelay={300}
                        inputProps={{ placeholder: selected.length ? "" : "查找记录" }}
                        onChange={(items) => {
                            setRefState(null);
                            const t = (items?.[0] as ResultTag) ?? null;
                            props.onChange(
                                t ? String(t.key) : null,
                                t ? t.name : null,
                                t ? (t.sourceKey ?? activeKey) : null);
                        }}
                    />
                </Stack.Item>
            </Stack>
            {refState === "missing" &&
                <Stack horizontal verticalAlign="center" tokens={{ childrenGap: 6 }}>
                    <Icon iconName="Warning" styles={{ root: { color: "#8a6d00" } }} />
                    <Text variant="small" styles={{ root: { color: "#8a6d00" } }}>
                        引用的记录不存在或已被删除(值:{props.value})
                    </Text>
                </Stack>}
        </Stack>
    );
};
