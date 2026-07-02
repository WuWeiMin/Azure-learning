using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Messages;
using Microsoft.Xrm.Sdk.Metadata;
using Microsoft.Xrm.Sdk.Query;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace SohuCom.Crm2015.Plugins.AutoNumber
{
    public class EntityRecordPreCreate : PluginBase
    {
        /// <summary>
        /// Initializes a new instance of the <see cref="EntityRecordPreCreate"/> class.
        /// </summary>
        /// <param name="unsecure">Contains public (unsecured) configuration information.</param>
        /// <param name="secure">Contains non-public (secured) configuration information. 
        /// When using Microsoft Dynamics CRM for Outlook with Offline Access, 
        /// the secure string is not passed to a plug-in that executes while the client is offline.</param>
        public EntityRecordPreCreate(string unsecure, string secure)
            : base(typeof(EntityRecordPreCreate))
        {
        }
        /// <summary>
        /// Main entry point for he business logic that the plug-in is to execute.
        /// </summary>
        /// <param name="localContext">The <see cref="LocalPluginContext"/> which contains the
        /// <see cref="IPluginExecutionContext"/>,
        /// <see cref="IOrganizationService"/>
        /// and <see cref="ITracingService"/>
        /// </param>
        /// <remarks>
        /// For improved performance, Microsoft Dynamics CRM caches plug-in instances.
        /// The plug-in's Execute method should be written to be stateless as the constructor
        /// is not called for every invocation of the plug-in. Also, multiple system threads
        /// could execute the plug-in at the same time. All per invocation state information
        /// is stored in the context. This means that you should not use global variables in plug-ins.
        /// </remarks>
        protected override void ExecuteCrmPlugin(LocalPluginContext localContext)
        {
            if (localContext == null)
            {
                throw new ArgumentNullException("localContext");
            }
            IPluginExecutionContext context = localContext.PluginExecutionContext;
            IOrganizationService service = localContext.OrganizationServiceSystem;
            Entity target = context.InputParameters["Target"] as Entity;
            Guid entityId = target.Id;
            //自动生成续号这个注册在实体的Pre Create上
            if (context.MessageName.ToLower() == "create")
            {
                string entityName = localContext.LogicalName;//当前触发插件的实体名

                //查找触发插件的实体 对应的 有效的，启用的自动编号配置
                string fetchConfig = string.Format(@"<fetch version='1.0' output-format='xml-platform' mapping='logical' distinct='false'>
  <entity name='ab_autonumber'>
    <attribute name='ab_autonumberid' />
    <attribute name='ab_name' />
    <attribute name='ab_attributename' />
    <attribute name='ab_startnumber' />
    <attribute name='ab_incrementvalue' />
    <attribute name='createdon' />
    <order attribute='ab_name' descending='false' />
    <filter type='and'>
      <condition attribute='ab_entityname' operator='eq' value='{0}' />
      <condition attribute='ab_isenabled' operator='eq' value='1' />
      <condition attribute='statecode' operator='eq' value='0' />
    </filter>
  </entity>
</fetch>", entityName);
                EntityCollection resultConfig = service.RetrieveMultiple(new FetchExpression(fetchConfig));
                foreach (Entity eConfig in resultConfig.Entities)
                {
                    #region 锁表
                    Entity uConfig = new Entity("ab_autonumber");
                    uConfig.Id = eConfig.Id;
                    uConfig.Attributes["ab_virtualfield"] = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
                    service.Update(uConfig);//更配置表（生成DB锁），防止重号
                    #endregion
                    #region 设置种子 开始值和递增量 默认是1
                    int startnumber = 1;//种子开始值
                    int incrementvalue = 1;//种子递增量
                    if (eConfig.Attributes.Contains("ab_incrementvalue")
                        && eConfig.Attributes["ab_incrementvalue"] != null)
                    {
                        incrementvalue = int.Parse(eConfig.Attributes["ab_incrementvalue"].ToString());
                    }
                    if (eConfig.Attributes.Contains("ab_startnumber")
                        && eConfig.Attributes["ab_startnumber"] != null)
                    {
                        startnumber = int.Parse(eConfig.Attributes["ab_startnumber"].ToString());
                    }

                    #endregion
                    //自动编号生成后指定的字段名称（编号生成在哪个字段上）
                    string autonumberfield = eConfig.Attributes["ab_attributename"].ToString();

                    string configId = eConfig.Id.ToString(); //自动编号配置
                    //自动编号配置明细
                    #region 查询有效的配置明细 
                    string fetchConfigDetail = string.Format(@"<fetch version='1.0' output-format='xml-platform' mapping='logical' distinct='false'>
  <entity name='ab_autonumberdetail'>
    <attribute name='ab_autonumberdetailid' />
    <attribute name='ab_type' />
    <attribute name='ab_suffix' />
    <attribute name='ab_prefix' />
    <attribute name='ab_value' />
    <attribute name='ab_entityname' />
    <attribute name='ab_attributename' />
    <attribute name='ab_format' />
    <attribute name='ab_sort' />
    <order attribute='ab_sort' descending='false' />
    <filter type='and'>
      <condition attribute='statecode' operator='eq' value='0' />
      <condition attribute='ab_autonumber_r1' operator='eq' uitype='ab_autonumber' value='{0}' />
    </filter>
  </entity>
</fetch>", configId);
                    EntityCollection resultDetails = service.RetrieveMultiple(new FetchExpression(fetchConfigDetail));
                    #endregion
                    string groupstring = "";//根据配置明细生成的分组字符串
                    foreach (Entity eConfigDetail in resultDetails.Entities)
                    {
                        string numberString = ""; //明细生成的编号段
                        #region 配置明细信息
                        //10静态值 20实体属性 30当前日期 40种子（递增值）
                        OptionSetValue osvValue = eConfigDetail.Attributes["ab_type"] as OptionSetValue;
                        //前缀
                        string preFix = eConfigDetail.Attributes.Contains("ab_prefix") ? eConfigDetail.Attributes["ab_prefix"] as string : "";
                        //后缀
                        string sufFix = eConfigDetail.Attributes.Contains("ab_suffix") ? eConfigDetail.Attributes["ab_suffix"] as string : "";
                        //自动编号明细值（只有 10静态值 20选项集 30lookup 才有实际用途）
                        string stringValue = eConfigDetail.Attributes.Contains("ab_value") ? eConfigDetail.Attributes["ab_value"] as string : "";
                        //格式化串
                        string formatString = eConfigDetail.Attributes.Contains("ab_format") ? eConfigDetail.Attributes["ab_format"] as string : "";
                        #endregion

                        if (osvValue.Value == 10)
                        {

                        }
                        else if (osvValue.Value == 20)
                        {
                            object objAttri = target.Attributes[stringValue];
                            string attributeTypeName = GetAttributeType(service, localContext.LogicalName, stringValue);
                            switch (attributeTypeName)
                            {
                                case "picklist":
                                    int opitionValue = ((OptionSetValue)objAttri).Value;
                                    stringValue = GetoptionsetText(entityName, stringValue, opitionValue, service);
                                    break;
                                case "lookup":
                                    EntityReference lookupRef = objAttri as EntityReference;
                                    string lookupValue = lookupRef.Id.ToString();
                                    string relEntityName = eConfigDetail.Attributes.Contains("ab_entityname") ? eConfigDetail.Attributes["ab_entityname"] as string : "";
                                    string relEntityAttribute = eConfigDetail.Attributes.Contains("ab_attributename") ? eConfigDetail.Attributes["ab_attributename"] as string : "";
                                    Entity relEntity = service.Retrieve(relEntityName, lookupRef.Id, new ColumnSet(relEntityAttribute));
                                    string attrTypeName = GetAttributeType(service, relEntityName, relEntityAttribute);
                                    #region lookup属性 关联实体对应的属性 处理，仅仅支持 picklist lookup datetime string的处理
                                    if (attrTypeName == "picklist")
                                    {
                                        int refpotionValue = ((OptionSetValue)relEntity.Attributes[relEntityAttribute]).Value;
                                        stringValue = GetoptionsetText(relEntityName, relEntityAttribute, refpotionValue, service);
                                    }
                                    else if (attrTypeName == "lookup")
                                    {
                                        EntityReference refLookup = relEntity.Attributes[relEntityAttribute] as EntityReference;
                                        stringValue = refLookup.Name;

                                    }
                                    else if (attrTypeName == "datetime")
                                    {
                                        DateTime refDateTime = DateTime.Parse(relEntity.Attributes[relEntityAttribute].ToString());
                                        stringValue = refDateTime.ToString(formatString);
                                    }
                                    else
                                    {
                                        stringValue = relEntity.Attributes[relEntityAttribute].ToString();
                                    }
                                    #endregion
                                    break;
                                case "datetime":
                                    DateTime dtValue = DateTime.Parse(objAttri.ToString());
                                    stringValue = dtValue.ToString(formatString);
                                    break;
                                case "string":
                                    stringValue = objAttri.ToString();
                                    break;
                                default:
                                    stringValue = objAttri.ToString();
                                    break;
                            }

                        }
                        else if (osvValue.Value == 30)
                        {
                            stringValue = DateTime.Now.ToString(formatString);
                        }
                        else if (osvValue.Value == 40)
                        {
                            stringValue = "{0}";
                        }

                        numberString = preFix + stringValue + sufFix;
                        groupstring += numberString;
                    }
                    string fetchSeed = string.Format(@"<fetch version='1.0' output-format='xml-platform' mapping='logical' distinct='false' no-lock='false'>
  <entity name='ab_autonumberseed'>
    <attribute name='ab_autonumberseedid' />
    <attribute name='ab_name' />
    <attribute name='ab_serialnumber' />
    <filter type='and'>
      <condition attribute='ab_name' operator='eq'  value='{0}' />
    </filter>
  </entity>
</fetch>", groupstring);
                    EntityCollection resultSeed = service.RetrieveMultiple(new FetchExpression(fetchSeed));
                    string number = string.Empty;
                    if (resultSeed.Entities.Count > 0)
                    {
                        //找到对应的种子，取出当前编号备用，然后加上递增量
                        Entity entSeed = resultSeed[0];
                        number = entSeed["ab_serialnumber"].ToString();
                        entSeed["ab_serialnumber"] = int.Parse(number) + incrementvalue;
                        service.Update(entSeed);
                    }
                    else
                    {
                        //没找到种子，生成一个种子（种子的序号值=开始值+地增量）
                        Entity entSeed = new Entity("ab_autonumberseed");
                        entSeed["ab_name"] = groupstring;
                        entSeed["ab_serialnumber"] = startnumber + incrementvalue;
                        service.Create(entSeed);
                        number = startnumber.ToString();//开始值
                    }
                    if (number.Length < 4)
                    {
                        groupstring = string.Format(groupstring, number.PadLeft(4, '0'));
                    }
                    else
                    {
                        groupstring = string.Format(groupstring, number);
                    }
                    //为实体指定的字段（自动编号配置上指定的） 赋值生成的编号
                    target.Attributes[autonumberfield] = groupstring;
                }

            }

        }

        /// <summary>
        /// 获取PickList值的标签
        /// </summary>
        /// <param name="entityName">实体名</param>
        /// <param name="attributeName">Picklist属性名</param>
        /// <param name="optionSetValue">PickList值</param>
        /// <param name="service">Crm组织服务</param>
        /// <returns></returns>
        static string GetoptionsetText(string entityName, string attributeName, int optionSetValue, IOrganizationService service)
        {
            string AttributeName = attributeName;
            string EntityLogicalName = entityName;
            RetrieveEntityRequest retrieveDetails = new RetrieveEntityRequest
            {
                EntityFilters = EntityFilters.All,
                LogicalName = EntityLogicalName
            };
            RetrieveEntityResponse retrieveEntityResponseObj = (RetrieveEntityResponse)service.Execute(retrieveDetails);
            Microsoft.Xrm.Sdk.Metadata.EntityMetadata metadata = retrieveEntityResponseObj.EntityMetadata;
            Microsoft.Xrm.Sdk.Metadata.PicklistAttributeMetadata picklistMetadata = metadata.Attributes.FirstOrDefault(attribute => String.Equals(attribute.LogicalName, attributeName, StringComparison.OrdinalIgnoreCase)) as Microsoft.Xrm.Sdk.Metadata.PicklistAttributeMetadata;
            Microsoft.Xrm.Sdk.Metadata.OptionSetMetadata options = picklistMetadata.OptionSet;
            IList<OptionMetadata> OptionsList = (from o in options.Options
                                                 where o.Value.Value == optionSetValue
                                                 select o).ToList();
            string optionsetLabel = (OptionsList.First()).Label.UserLocalizedLabel.Label;
            return optionsetLabel;
        }

        /// <summary>
        /// 获取实体属性的类型
        /// </summary>
        /// <param name="service">CRM组织服务</param>
        /// <param name="entityName">实体名</param>
        /// <param name="attributeName">属性名</param>
        /// <returns></returns>
        static string GetAttributeType(IOrganizationService service, string entityName, string attributeName)
        {
            RetrieveAttributeRequest attributeRequest = new RetrieveAttributeRequest
            {
                EntityLogicalName = entityName,
                LogicalName = attributeName,
                RetrieveAsIfPublished = false
            };
            // Execute the request
            RetrieveAttributeResponse attributeResponse =
                (RetrieveAttributeResponse)service.Execute(attributeRequest);
            string attributeTypeName = attributeResponse.AttributeMetadata.AttributeType.ToString().ToLower();
            return attributeTypeName;
        }
    }
}
