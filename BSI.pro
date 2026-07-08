QT       += core gui widgets sql xml printsupport

CONFIG += c++17

TARGET = ISMS
TEMPLATE = app

INCLUDEPATH += src

SOURCES += \
    src/main.cpp \
    src/app/AppContext.cpp \
    src/app/AppPaths.cpp \
    src/catalog/GrundschutzImporter.cpp \
    src/catalog/XmlTextExtractor.cpp \
    src/persistence/CatalogRepository.cpp \
    src/persistence/Database.cpp \
    src/persistence/MeasureRepository.cpp \
    src/persistence/ProjectRepository.cpp \
    src/persistence/TargetObjectRepository.cpp \
    src/services/BausteinRecommendationService.cpp \
    src/services/ReportExporter.cpp \
    src/services/ReportService.cpp \
    src/ui/MainWindow.cpp \
    src/ui/dialogs/BausteinRecommendationDialog.cpp \
    src/ui/dialogs/MeasureDialog.cpp \
    src/ui/dialogs/ProjectOpenDialog.cpp \
    src/ui/dialogs/ProjectDialog.cpp \
    src/ui/dialogs/ReportDialog.cpp \
    src/ui/dialogs/TargetObjectDialog.cpp \
    src/ui/models/BausteinTreeModel.cpp \
    src/ui/models/MeasureTableModel.cpp \
    src/ui/models/ReportTableModel.cpp \
    src/ui/models/RequirementTableModel.cpp \
    src/ui/models/TargetObjectTreeModel.cpp

HEADERS += \
    src/app/AppContext.h \
    src/app/AppPaths.h \
    src/catalog/GrundschutzImporter.h \
    src/catalog/XmlTextExtractor.h \
    src/domain/ApplicabilityStatus.h \
    src/domain/AssessmentStatus.h \
    src/domain/BausteinApplicability.h \
    src/domain/Baustein.h \
    src/domain/Measure.h \
    src/domain/MeasureStatus.h \
    src/domain/Project.h \
    src/domain/ProtectionNeed.h \
    src/domain/ReportRow.h \
    src/domain/Requirement.h \
    src/domain/RequirementAssessment.h \
    src/domain/RequirementLevel.h \
    src/domain/Standard.h \
    src/domain/TargetObject.h \
    src/domain/TargetObjectType.h \
    src/persistence/CatalogRepository.h \
    src/persistence/Database.h \
    src/persistence/MeasureRepository.h \
    src/persistence/ProjectRepository.h \
    src/persistence/TargetObjectRepository.h \
    src/services/BausteinRecommendationService.h \
    src/services/ReportExporter.h \
    src/services/ReportService.h \
    src/ui/MainWindow.h \
    src/ui/dialogs/BausteinRecommendationDialog.h \
    src/ui/dialogs/MeasureDialog.h \
    src/ui/dialogs/ProjectOpenDialog.h \
    src/ui/dialogs/ProjectDialog.h \
    src/ui/dialogs/ReportDialog.h \
    src/ui/dialogs/TargetObjectDialog.h \
    src/ui/models/BausteinTreeModel.h \
    src/ui/models/MeasureTableModel.h \
    src/ui/models/ReportTableModel.h \
    src/ui/models/RequirementTableModel.h \
    src/ui/models/TargetObjectTreeModel.h

qnx: target.path = /tmp/$${TARGET}/bin
else: unix:!android: target.path = /opt/$${TARGET}/bin
!isEmpty(target.path): INSTALLS += target
