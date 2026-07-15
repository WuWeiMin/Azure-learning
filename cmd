GET [组织URL]/api/data/v9.2/EntityDefinitions?$select=LogicalName&$expand=Attributes($select=LogicalName;$filter=LogicalName eq 'yourfieldname')


fetch("/api/data/v9.2/EntityDefinitions?$select=LogicalName&$expand=Attributes($select=LogicalName;$filter=LogicalName eq 'aia_utilizationbalance')")
  .then(r => r.json())
  .then(d => {
    const hits = d.value.filter(e => e.Attributes.length > 0).map(e => e.LogicalName);
    console.log(`共 ${hits.length} 个表:`, hits);
  });

https://你的环境.crm5.dynamics.com/api/data/v9.2/EntityDefinitions(LogicalName='aia_ebplan')/Attributes(LogicalName='aia_benefitlimittype')/Microsoft.Dynamics.CRM.PicklistAttributeMetadata?$expand=OptionSet($select=Options)
fetch("/api/data/v9.2/EntityDefinitions(LogicalName='aia_ebplan')/Attributes(LogicalName='aia_benefitlimittype')/Microsoft.Dynamics.CRM.PicklistAttributeMetadata?$expand=OptionSet($select=Options)")
  .then(r => r.json())
  .then(d => {
    d.OptionSet.Options.forEach(o =>
      console.log(o.Value, '=>', o.Label.UserLocalizedLabel.Label));
  });


fetch("/api/data/v9.2/EntityDefinitions(LogicalName='aia_ebplan')/Attributes(LogicalName='aia_benefitlimittype')/Microsoft.Dynamics.CRM.MultiSelectPicklistAttributeMetadata?$expand=OptionSet($select=Options)")
  .then(r => r.json())
  .then(d => {
    d.OptionSet.Options.forEach(o =>
      console.log(o.Value, '=>', o.Label.UserLocalizedLabel.Label));
  });

fetch("/api/data/v9.2/GlobalOptionSetDefinitions(Name='选项集名')")
  .then(r => r.json())
  .then(d => {
    d.Options.forEach(o =>
      console.log(o.Value, '=>', o.Label.UserLocalizedLabel.Label));
  });


const field = 'aia_benefitlimittype';  // 改成你的字段名

fetch(`/api/data/v9.2/EntityDefinitions?$select=LogicalName&$expand=Attributes($select=LogicalName,AttributeType;$filter=LogicalName eq '${field}')`)
  .then(r => r.json())
  .then(async d => {
    const hits = d.value.filter(e => e.Attributes.length > 0);
    console.log(`字段 ${field} 存在于 ${hits.length} 个实体:`, hits.map(e => e.LogicalName));

    for (const e of hits) {
      const type = e.Attributes[0].AttributeType; // Picklist 或 Virtual(多选)
      const metaType = type === 'Picklist'
        ? 'Microsoft.Dynamics.CRM.PicklistAttributeMetadata'
        : 'Microsoft.Dynamics.CRM.MultiSelectPicklistAttributeMetadata';

      const res = await fetch(`/api/data/v9.2/EntityDefinitions(LogicalName='${e.LogicalName}')/Attributes(LogicalName='${field}')/${metaType}?$expand=OptionSet($select=Options)`);
      if (!res.ok) { console.log(e.LogicalName, ': 非picklist类型,跳过'); continue; }
      const meta = await res.json();

      console.log(`—— ${e.LogicalName} ——`);
      meta.OptionSet.Options.forEach(o =>
        console.log('  ', o.Value, '=>', o.Label.UserLocalizedLabel.Label));
    }
  });

fetch("/api/data/v9.2/EntityDefinitions(LogicalName='aia_ebplan')/Attributes(LogicalName='aia_benefitlimittype')/Microsoft.Dynamics.CRM.MultiSelectPicklistAttributeMetadata?$expand=OptionSet($select=Options)")
  .then(r => r.json())
  .then(d => {
    d.OptionSet.Options.forEach(o =>
      console.log(o.Value, '=>', o.Label.UserLocalizedLabel.Label));
  });



fetch("/api/data/v9.2/sdkmessageprocessingsteps?$select=name,filteringattributes,stage,mode&$filter=contains(name,'SetUtilizationBalance')")
  .then(r => r.json())
  .then(d => d.value.forEach(s =>
    console.log(s.name, '| stage:', s.stage, '| filteringattributes:', s.filteringattributes || '(全部字段)')));


fetch("/api/data/v9.2/north52_formulas(1677d15b-a4ef-4a5c-a724-aa1caacbb63c)")
  .then(r => r.json())
  .then(d => {
    // 先把所有字段名和值打出来,找存储过滤字段的那个
    Object.entries(d)
      .filter(([k, v]) => typeof v === 'string' && v.length > 0 && !k.startsWith('@'))
      .forEach(([k, v]) => console.log(k, '=>', v.substring(0, 300)));
  });

(function(){
  const frames = [window, ...document.querySelectorAll('iframe')].map(f => {
    try { return f.contentDocument || f.document || document; } catch(e) { return null; }
  }).filter(Boolean);
  for (const doc of frames) {
    const sel = doc.querySelector('#metadataproperty');
    if (sel) {
      console.log([...sel.selectedOptions].map(o => o.value + ' => ' + o.text).join('\n'));
      return;
    }
  }
  console.log('没找到#metadataproperty,检查frame context');
})();
