/* ============================================================
   Dynamics 365 解决方案组件明细查询 - SQL(TDS Endpoint)版本

   重要限制：
   Dataverse的SQL 4.0只暴露"数据(Data)"表，不暴露"元数据(Metadata)"。
   所以本查询只能反查出 ismetadata = 0 的组件类型的真实名称，比如
   Workflow、WebResource、SavedQuery、SystemForm、Role、插件相关等。

   Entity(表)、Attribute(字段)、OptionSet(选项集)、EntityRelationship(关系)
   这几类 ismetadata = 1，SQL查不到名字（Dataverse没有把元数据定义
   暴露成可SQL查询的表），这部分仍需用之前的JS脚本
   (d365_solution_components_export_v3.js)，走Web API的
   EntityDefinitions/Attributes等metadata接口去反查。

   componenttypename、ismetadataname 这两列由TDS Endpoint自动提供，
   不需要额外反查componenttype的含义。

   使用方法：把下面的 'AIAXRPSLN_2607_1' 改成你的solution唯一名，
   在SSMS/XrmToolBox等能连Dataverse SQL Endpoint的工具里执行即可。
   ============================================================ */

SELECT
    sc.componenttype                                   AS 类型编号,
    sc.componenttypename                                AS 类型名称,
    sc.ismetadataname                                   AS 元数据还是数据,
    COALESCE(
        wf.name,
        wr.name,
        sq.name,
        sf.name,
        rl.name,
        rep.name,
        tpl.title,
        pa.name,
        pt.name,
        step.name,
        stepimg.name,
        se.name,
        cr.name,
        fsp.name,
        am.name,
        capi.uniquename,
        capireq.uniquename,
        capiresp.uniquename,
        sla.name,
        mop.name,
        mopi.name,
        connref.connectionreferencedisplayname,
        envvar.displayname,
        dr.name,
        hr.name,
        sm.sitemapnameunique,
        chart.name
    )                                                    AS 名称,
    CASE
        WHEN sc.ismetadata = 1
            THEN N'元数据类型(Entity/Attribute/OptionSet/Relationship)，SQL无法反查，请用JS脚本'
        WHEN COALESCE(
                wf.name, wr.name, sq.name, sf.name, rl.name, rep.name, tpl.title,
                pa.name, pt.name, step.name, stepimg.name, se.name, cr.name, fsp.name,
                am.name, capi.uniquename, capireq.uniquename, capiresp.uniquename,
                sla.name, mop.name, mopi.name, connref.connectionreferencedisplayname,
                envvar.displayname, dr.name, hr.name, sm.sitemapnameunique, chart.name
             ) IS NOT NULL
            THEN N'成功'
        ELSE N'失败(疑似孤儿引用，或该数据类型暂未加入JOIN列表)'
    END                                                  AS 反查状态,
    sc.objectid                                          AS ObjectId,
    sc.rootcomponentbehavior                             AS RootComponentBehavior
FROM solutioncomponent sc
LEFT JOIN workflow                    wf       ON sc.componenttype = 29  AND sc.objectid = wf.workflowid
LEFT JOIN webresource                 wr       ON sc.componenttype = 61  AND sc.objectid = wr.webresourceid
LEFT JOIN savedquery                  sq       ON sc.componenttype = 26  AND sc.objectid = sq.savedqueryid
LEFT JOIN systemform                  sf       ON sc.componenttype = 60  AND sc.objectid = sf.formid
LEFT JOIN role                        rl       ON sc.componenttype = 20  AND sc.objectid = rl.roleid
LEFT JOIN report                      rep      ON sc.componenttype = 31  AND sc.objectid = rep.reportid
LEFT JOIN template                    tpl      ON sc.componenttype = 36  AND sc.objectid = tpl.templateid
LEFT JOIN pluginassembly              pa       ON sc.componenttype = 91  AND sc.objectid = pa.pluginassemblyid
LEFT JOIN plugintype                  pt       ON sc.componenttype = 90  AND sc.objectid = pt.plugintypeid
LEFT JOIN sdkmessageprocessingstep    step     ON sc.componenttype = 92  AND sc.objectid = step.sdkmessageprocessingstepid
LEFT JOIN sdkmessageprocessingstepimage stepimg ON sc.componenttype = 93 AND sc.objectid = stepimg.sdkmessageprocessingstepimageid
LEFT JOIN serviceendpoint             se       ON sc.componenttype = 95  AND sc.objectid = se.serviceendpointid
LEFT JOIN connectionrole              cr       ON sc.componenttype = 63  AND sc.objectid = cr.connectionroleid
LEFT JOIN fieldsecurityprofile        fsp      ON sc.componenttype = 70  AND sc.objectid = fsp.fieldsecurityprofileid
LEFT JOIN appmodule                   am       ON sc.componenttype = 80  AND sc.objectid = am.appmoduleid
LEFT JOIN customapi                   capi     ON sc.componenttype = 136 AND sc.objectid = capi.customapiid
LEFT JOIN customapirequestparameter   capireq  ON sc.componenttype = 137 AND sc.objectid = capireq.customapirequestparameterid
LEFT JOIN customapiresponseproperty   capiresp ON sc.componenttype = 138 AND sc.objectid = capiresp.customapiresponsepropertyid
LEFT JOIN sla                         sla      ON sc.componenttype = 152 AND sc.objectid = sla.slaid
LEFT JOIN mobileofflineprofile        mop      ON sc.componenttype = 161 AND sc.objectid = mop.mobileofflineprofileid
LEFT JOIN mobileofflineprofileitem    mopi     ON sc.componenttype = 162 AND sc.objectid = mopi.mobileofflineprofileitemid
LEFT JOIN connectionreference         connref  ON sc.componenttype = 372 AND sc.objectid = connref.connectionreferenceid
LEFT JOIN environmentvariabledefinition envvar ON sc.componenttype = 380 AND sc.objectid = envvar.environmentvariabledefinitionid
LEFT JOIN duplicaterule               dr       ON sc.componenttype = 44  AND sc.objectid = dr.duplicateruleid
LEFT JOIN hierarchyrule               hr       ON sc.componenttype = 65  AND sc.objectid = hr.hierarchyruleid
LEFT JOIN sitemap                     sm       ON sc.componenttype = 62  AND sc.objectid = sm.sitemapid
LEFT JOIN savedqueryvisualization     chart    ON sc.componenttype = 59  AND sc.objectid = chart.savedqueryvisualizationid
WHERE sc.solutionid = (
    SELECT solutionid
    FROM solution
    WHERE uniquename = 'AIAXRPSLN_2607_1'   -- <-- 改成你的solution唯一名
)
ORDER BY sc.componenttype, 名称;
