/*
  Q Light Controller Plus
  kahostageimport.h

  Copyright (c) Massimo Callegari
  Copyright (c) KAHO

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0.txt

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/

#ifndef KAHOSTAGEIMPORT_H
#define KAHOSTAGEIMPORT_H

#include <QObject>
#include <QUrl>

class ContextManager;
class Doc;

/**
 * Imports the stage layout exported by the KahoStage Minecraft plugin
 * (KahoStage-scene.json): fixture positions and orientations for the
 * 2D / 3D views and the trusses, without touching the programming.
 */
class KahoStageImport final : public QObject
{
    Q_OBJECT

public:
    KahoStageImport(Doc *doc, ContextManager *ctx, QObject *parent = nullptr);

    /** @return a short report for the user, empty string on success messages too */
    Q_INVOKABLE QString importScene(const QUrl &fileUrl);

private:
    Doc *m_doc;
    ContextManager *m_contextManager;
};

#endif // KAHOSTAGEIMPORT_H
