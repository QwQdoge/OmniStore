"""Runtime regression test for the real details component (requires PySide6).

Run with QML_IMPORT_PATH and LD_LIBRARY_PATH pointing at the built MeoUI module.
Pass an output tmp directory; no generated modules are written in the checkout.
"""
import sys
from pathlib import Path

from PySide6.QtCore import QObject, Property, Signal, QUrl, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QJSValue, QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow


class State(QObject):
    changed = Signal()

    def __init__(self):
        super().__init__()
        self.values = {}

    def insert(self, key, value):
        self.values[key] = value
        self.changed.emit()

    selectedApp = Property('QVariantMap', lambda self: self.values.get('selectedApp', {}), notify=changed)
    installPlan = Property('QVariantMap', lambda self: self.values.get('installPlan', {}), notify=changed)
    busy = Property(bool, lambda self: self.values.get('busy', False), notify=changed)
    available = Property(bool, lambda self: self.values.get('available', True), notify=changed)
    planning = Property(bool, lambda self: self.values.get('planning', False), notify=changed)
    errorMessage = Property(str, lambda self: self.values.get('errorMessage', ''), notify=changed)


class Backend(State):
    def __init__(self):
        super().__init__()
        self.insert("selectedApp", {})
        self.insert("busy", False)
        self.insert("errorMessage", "")
        self.requests = []

    @Slot(str, str)
    def loadDetails(self, package, source):
        self.requests.append((package, source))


class Transactions(State):
    def __init__(self):
        super().__init__()
        for key, value in dict(installPlan={}, planning=False, busy=False,
                               available=True, errorMessage="").items():
            self.insert(key, value)
        self.clears = 0
        self.requests = []

    @Slot()
    def clearInstallPlan(self):
        self.clears += 1
        self.insert("installPlan", {})

    @Slot(str, str, str)
    def planInstall(self, package, source, url):
        self.requests.append((package, source, url))


app = QGuiApplication(sys.argv)
output = Path(sys.argv[1]).resolve()
module = output / "OmniStore" / "Native"
module.mkdir(parents=True, exist_ok=True)
components = Path(__file__).resolve().parents[1] / "qml" / "components"
names = ["PageHeading", "InstallPlanReview"]
(module / "qmldir").write_text("module OmniStore.Native\n" + "".join(
    f"{name} 1.0 {name}.qml\n" for name in names))
for name in names:
    target = module / f"{name}.qml"
    if not target.exists():
        target.symlink_to(components / f"{name}.qml")
engine = QQmlApplicationEngine()
engine.addImportPath(str(output))
backend, transactions = Backend(), Transactions()
engine.rootContext().setContextProperty("backend", backend)
engine.rootContext().setContextProperty("transactions", transactions)
engine.loadData(('''import QtQuick
import QtQuick.Controls
ApplicationWindow {
    width: 1000; height: 900; visible: true
    Loader { objectName: "detailsLoader"; anchors.fill: parent; source: "%s" }
}''' % QUrl.fromLocalFile(str(components / 'AppDetailsPane.qml')).toString()).encode())
app.processEvents()
assert engine.rootObjects(), "details window did not load"
window = engine.rootObjects()[0]
# The content item owns the Loader; access its loaded item without duplicating UI.
loader = window.findChild(QObject, "detailsLoader")
pane = loader.property("item")
assert pane is not None, "details pane did not instantiate"
pane.setProperty('fallbackApp', dict(id='demo', name='Demo', primary_source='Pacman', installed=True,
    url='https://example.org/native', variants=[
        dict(id='demo', source='Pacman', installed=True, version='1'),
        dict(id='org.example.Demo', source='Flatpak', installed=False, version='2'),
        dict(id='org.example.Demo.Beta', source='Flatpak', installed=False, version='3')]))
backend.insert('selectedApp', dict(id='demo', source='Native', installed=True,
    variants=[dict(id='demo', source='Native')]))
app.processEvents()
assert len(pane.property('sourceVariants')) == 3, 'details discarded alternatives'
assert pane.property('selectedInstalled')
transactions.insert('installPlan', dict(request=dict(name='demo', source='Pacman'), planHash='old'))
engine.newQObject(pane).property('chooseSource').call([QJSValue('Flatpak'), QJSValue('org.example.Demo')])
app.processEvents()
assert backend.requests[-1] == ('org.example.Demo', 'Flatpak')
assert not pane.property('selectedInstalled'), 'aggregate installed state leaked to new source'
assert not pane.property('selectedMatches'), 'stale native details accepted for Flatpak'
assert not pane.property('planMatches'), 'stale install plan survived source switch'
assert engine.newQObject(pane).property('packageIdentity').call().toString() == 'org.example.Demo'
assert engine.newQObject(pane).property('installUrl').call().toString() == '', 'native URL leaked to Flatpak'
backend.insert('selectedApp', dict(id='org.example.Demo', source='Flatpak', installed=False,
    description='Flatpak details', variants=[dict(source='Flatpak', id='org.example.Demo')]))
app.processEvents()
assert pane.property('selectedMatches')
assert len(pane.property('sourceVariants')) == 3
engine.newQObject(pane).property('chooseSource').call([QJSValue('Flatpak'), QJSValue('org.example.Demo.Beta')])
app.processEvents()
assert backend.requests[-1] == ('org.example.Demo.Beta', 'Flatpak')
assert not pane.property('selectedMatches'), 'same-source different package reused stale details'
engine.newQObject(pane).property('chooseSource').call([QJSValue('Flatpak'), QJSValue('org.example.Demo')])
backend.insert('selectedApp', dict(id='org.example.Demo', source='Flatpak', installed=False))
transactions.insert('installPlan', dict(request=dict(name='org.example.Demo', source='Flatpak', url=None), planHash='new'))
app.processEvents()
assert pane.property('planMatches')
pane.findChild(QObject, 'installButton').clicked.emit()
assert transactions.requests == [('org.example.Demo', 'Flatpak', '')]
# Allow layout and rendering to complete before retaining a review image.
from PySide6.QtCore import QTimer
QTimer.singleShot(700, app.quit)
app.exec()
window.grabWindow().save(str(output / 'source-selection.png'))
print('PASS: source preservation, exact package selection, installed state, stale details/plan, URL isolation')
