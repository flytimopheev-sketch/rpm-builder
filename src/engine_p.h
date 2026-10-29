/*
 *  RPM Builder — внутренние помощники, общие для нескольких .cpp движка
 */
#pragma once
#include <QString>
#include <QDir>
#include <QLocale>
#include <QStandardPaths>

namespace EB {

inline QString configPath()
{
    return QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation)
         + QStringLiteral("/config.json");
}

inline QString expandTilde(const QString &p)
{
    if (p == QLatin1String("~"))
        return QDir::homePath();
    if (p.startsWith(QStringLiteral("~/")))
        return QDir::homePath() + p.mid(1);
    return p;
}

inline QString humanSize(qint64 bytes)
{
    if (bytes <= 0) return QStringLiteral("0 Б");
    const qint64 kb = bytes / 1024;
    if (kb < 1024) return QString::number(kb) + QStringLiteral(" КБ");
    const double mb = kb / 1024.0;
    if (mb < 1024.) return QString::number(mb, 'f', 1) + QStringLiteral(" МБ");
    return QString::number(mb / 1024., 'f', 2) + QStringLiteral(" ГБ");
}

} // namespace EB
