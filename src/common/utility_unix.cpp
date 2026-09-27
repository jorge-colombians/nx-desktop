/*
 * SPDX-FileCopyrightText: 2020 Nextcloud GmbH and Nextcloud contributors
 * SPDX-FileCopyrightText: 2014 ownCloud GmbH
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

#include "utility.h"
#include "config.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QStandardPaths>
#include <QtGlobal>
#include <QProcess>
#include <QRegularExpression>
#include <QString>
#include <QTextStream>

namespace OCC {

QVector<Utility::ProcessInfosForOpenFile> Utility::queryProcessInfosKeepingFileOpen(const QString &filePath)
{
    Q_UNUSED(filePath)
    return {};
}

void Utility::setupFavLink(const QString &folder)
{
    // Nautilus: add to ~/.config/gtk-3.0/bookmarks
    QFile gtkBookmarks(QDir::homePath() + QLatin1String("/.config/gtk-3.0/bookmarks"));
    const auto folderUrl = QUrl::fromLocalFile(folder).toEncoded();
    if (!gtkBookmarks.open(QFile::ReadWrite)) {
        qCWarning(lcUtility).nospace() << "failed to set up fav link"
            << " folder=" << folder
            << " error=" << gtkBookmarks.error()
            << " errorString=" << gtkBookmarks.errorString();
        return;
    }

    auto places = gtkBookmarks.readAll();
    if (places.contains(folderUrl)) {
        qCDebug(lcUtility).nospace() << "fav link already exists"
            << " folder=" << folder
            << " folderUrl=" << folderUrl;
        return;
    }

    places += folderUrl;
    gtkBookmarks.reset();
    gtkBookmarks.write(places + '\n');
}

void Utility::removeFavLink(const QString &folder)
{
    Q_UNUSED(folder)
}

// returns the autostart directory the linux way
// and respects the XDG_CONFIG_HOME env variable
static QString getUserAutostartDir()
{
    QString config = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation);
    config += QLatin1String("/autostart/");
    return config;
}

bool Utility::hasSystemLaunchOnStartup(const QString &appName)
{
    Q_UNUSED(appName)
    return false;
}

bool Utility::hasLaunchOnStartup(const QString &appName)
{
    const QString desktopFileLocation = getUserAutostartDir() + appName + QLatin1String(".desktop");
    return QFile::exists(desktopFileLocation);
}

void Utility::migrateFavLink(const QString &folder)
{
    Q_UNUSED(folder)
}

void Utility::setupDesktopIni(const QString &folder, const QString localizedResourceName)
{
    Q_UNUSED(folder)
    Q_UNUSED(localizedResourceName)
}

QString Utility::syncFolderDisplayName(const QString &folder, const QString &displayName)
{
    Q_UNUSED(folder)
    Q_UNUSED(displayName)
    return {};
}

void Utility::setLaunchOnStartup(const QString &appName, const QString &guiName, bool enable)
{
    const auto userAutoStartPath = getUserAutostartDir();
    const QString desktopFileLocation = userAutoStartPath + appName + QLatin1String(".desktop");
    if (enable) {
        if (!QDir().exists(userAutoStartPath) && !QDir().mkpath(userAutoStartPath)) {
            qCWarning(lcUtility) << "Could not create autostart folder" << userAutoStartPath;
            return;
        }
        QFile iniFile(desktopFileLocation);
        if (!iniFile.open(QIODevice::WriteOnly)) {
            qCWarning(lcUtility) << "Could not write auto start entry" << desktopFileLocation;
            return;
        }
        // When running inside an AppImage, we need to set the path to the
        // AppImage instead of the path to the executable
        const QString appImagePath = qEnvironmentVariable("APPIMAGE");
        const bool runningInsideAppImage = !appImagePath.isNull() && QFile::exists(appImagePath);
        const QString executablePath = runningInsideAppImage ? appImagePath : QCoreApplication::applicationFilePath();

        QTextStream ts(&iniFile);
        ts << QLatin1String("[Desktop Entry]\n")
           << QLatin1String("Name=") << guiName << QLatin1Char('\n')
           << QLatin1String("GenericName=") << QLatin1String("File Synchronizer\n")
           << QLatin1String("Exec=\"") << executablePath << "\" --background\n"
           << QLatin1String("Terminal=") << "false\n"
           // inside an AppImage the icon is installed under the app id, see installAppImageDesktopEntry()
           << QLatin1String("Icon=") << (runningInsideAppImage ? QStringLiteral(LINUX_APPLICATION_ID) : QStringLiteral(APPLICATION_ICON_NAME)) << QLatin1Char('\n')
           << QLatin1String("Categories=") << QLatin1String("Network\n")
           << QLatin1String("Type=") << QLatin1String("Application\n")
           << QLatin1String("StartupNotify=") << "false\n"
           << QLatin1String("X-GNOME-Autostart-enabled=") << "true\n"
           << QLatin1String("X-GNOME-Autostart-Delay=10") << Qt::endl;
    } else {
        if (!QFile::remove(desktopFileLocation)) {
            qCWarning(lcUtility) << "Could not remove autostart desktop file";
        }
    }
}

bool Utility::launchOnStartupRequiresApproval()
{
    return false;
}

bool Utility::hasDarkSystray()
{
    return true;
}

QString Utility::getCurrentUserName()
{
    return {};
}

namespace {

// Quotes a path for use as the program in a .desktop Exec key (see the
// Desktop Entry Specification, "The Exec key").
QString quotedDesktopExecPath(const QString &path)
{
    QString escaped;
    for (const auto ch : path) {
        if (ch == u'"' || ch == u'`' || ch == u'$' || ch == u'\\') {
            escaped += u'\\';
        }
        escaped += ch;
    }
    // Exec is itself a string value, so backslashes get escaped once more.
    escaped.replace(QStringLiteral("\\"), QStringLiteral("\\\\"));
    return u'"' + escaped + u'"';
}

bool writeFileIfChanged(const QString &path, const QByteArray &content)
{
    QFile file(path);
    if (file.open(QIODevice::ReadOnly) && file.readAll() == content) {
        return true;
    }
    file.close();
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qCWarning(lcUtility) << "Could not write" << path << file.errorString();
        return false;
    }
    return file.write(content) == content.size();
}

// An AppImage is a single file that does not install anything, so it never
// shows up in the desktop's app menu. Copy the .desktop file and icon bundled
// inside it to the user's data dir, pointing Exec at the AppImage itself.
// This runs on every start, so moving or updating the AppImage keeps the entry
// working; TryExec hides the entry again if the AppImage gets deleted.
// The file name must be LINUX_APPLICATION_ID: that is the app id the window
// reports (QGuiApplication::desktopFileName) and the name the URI handler
// registration below refers to.
void installAppImageDesktopEntry(const QString &appImagePath)
{
    const auto appDir = qEnvironmentVariable("APPDIR");
    if (appDir.isEmpty()) {
        qCWarning(lcUtility) << "APPDIR not set, not adding the AppImage to the app menu";
        return;
    }

    const auto appId = QStringLiteral(LINUX_APPLICATION_ID);
    const auto dataHome = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);

    QFile bundledIcon(appDir + QStringLiteral("/usr/share/icons/hicolor/512x512/apps/" APPLICATION_ICON_NAME ".png"));
    const auto iconDir = dataHome + QStringLiteral("/icons/hicolor/512x512/apps");
    if (bundledIcon.open(QIODevice::ReadOnly) && QDir().mkpath(iconDir)) {
        writeFileIfChanged(iconDir + u'/' + appId + QStringLiteral(".png"), bundledIcon.readAll());
    } else {
        qCWarning(lcUtility) << "Could not install AppImage icon from" << bundledIcon.fileName();
    }

    QFile bundledDesktopFile(appDir + QStringLiteral("/usr/share/applications/") + appId + QStringLiteral(".desktop"));
    if (!bundledDesktopFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qCWarning(lcUtility) << "Could not read" << bundledDesktopFile.fileName();
        return;
    }

    const auto execPrefix = QStringLiteral("Exec=" APPLICATION_EXECUTABLE);
    const QRegularExpression iconKey(QStringLiteral("^(Icon(\\[[^\\]]*\\])?)="));
    QString content;
    QTextStream in(&bundledDesktopFile);
    while (!in.atEnd()) {
        const auto line = in.readLine();
        if (line.startsWith(execPrefix) && (line.size() == execPrefix.size() || line.at(execPrefix.size()) == u' ')) {
            content += QStringLiteral("Exec=") + quotedDesktopExecPath(appImagePath) + line.mid(execPrefix.size());
        } else if (const auto match = iconKey.match(line); match.hasMatch()) {
            content += match.captured(1) + u'=' + appId;
        } else {
            content += line;
        }
        content += u'\n';
        if (line == QStringLiteral("[Desktop Entry]")) {
            content += QStringLiteral("TryExec=") + appImagePath + u'\n';
        }
    }

    const auto applicationsDir = dataHome + QStringLiteral("/applications");
    if (!QDir().mkpath(applicationsDir)) {
        qCWarning(lcUtility) << "Could not create" << applicationsDir;
        return;
    }
    writeFileIfChanged(applicationsDir + u'/' + appId + QStringLiteral(".desktop"), content.toUtf8());
}

} // namespace

void Utility::registerUriHandlerForLocalEditing()
{
    const auto appImagePath = qEnvironmentVariable("APPIMAGE");
    const auto runningInsideAppImage = !appImagePath.isNull() && QFile::exists(appImagePath);

    if (!runningInsideAppImage) {
        // only register x-scheme-handler if running inside appImage
        return;
    }

    installAppImageDesktopEntry(appImagePath);

    // mirall.desktop.in must have an x-scheme-handler mime type specified
    const QString desktopFileName = QLatin1String(LINUX_APPLICATION_ID) + QLatin1String(".desktop");
    QProcess process;
    const QStringList args = {
        QLatin1String("default"),
        desktopFileName,
        QStringLiteral("x-scheme-handler/%1").arg(QStringLiteral(APPLICATION_URI_HANDLER_SCHEME))
    };
    process.start(QStringLiteral("xdg-mime"), args, QIODevice::ReadOnly);
    process.waitForFinished();
}

} // namespace OCC
