import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_url: urlField.text
    property alias cfg_apiKey: apiKeyField.text
    property alias cfg_pollInterval: pollSpin.value
    property alias cfg_iconStyle: iconStyleCombo.currentIndex

    Kirigami.FormLayout {
        QQC2.ComboBox {
            id: iconStyleCombo
            Kirigami.FormData.label: i18n("Icon:")
            model: [
                i18n("Colorful"),
                i18n("Monochrome (follow theme)"),
                i18n("Monochrome light"),
                i18n("Monochrome dark")
            ]
        }
        QQC2.TextField {
            id: urlField
            Kirigami.FormData.label: i18n("Web UI address:")
            placeholderText: "http://127.0.0.1:8384"
        }
        QQC2.TextField {
            id: apiKeyField
            Kirigami.FormData.label: i18n("API key:")
            placeholderText: i18n("Auto-detect from local config.xml")
            echoMode: TextInput.Password
        }
        QQC2.SpinBox {
            id: pollSpin
            Kirigami.FormData.label: i18n("Refresh every:")
            from: 1
            to: 300
            textFromValue: (value) => i18np("%1 second", "%1 seconds", value)
            valueFromText: (text) => parseInt(text)
        }
    }
}
