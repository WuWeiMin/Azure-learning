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
