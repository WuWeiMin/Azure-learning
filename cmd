function onFormLoad(executionContext) {
    var formContext = executionContext.getFormContext();
    Ripple.Utils.NotificationHelper.init(formContext, "en");

    formContext.data.entity.addOnSave(function (econtext) {
        econtext.getEventArgs().preventDefault(); // 拦住默认保存，不让原生弹窗出现
        handleSave(formContext);
    });
}

async function handleSave(formContext) {
    try {
        await formContext.data.save();
    } catch (error) {
        await Ripple.Utils.NotificationHelper.handlePluginError(error);
    }
}
