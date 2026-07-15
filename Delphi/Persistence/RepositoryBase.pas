unit RepositoryBase;

interface

uses
  System.SysUtils, System.Generics.Collections, IsmsDomain, GrundschutzImporter;

type
  TCatalogRepositoryBase = class
  public
    function ReplaceGrundschutzCatalog(const AImportResult: TGrundschutzImportResult;
      const ASourceXmlPath: string = ''): Boolean; virtual; abstract;
    function HasGrundschutzCatalog(const ACatalogVersion: string): Boolean; virtual; abstract;
    function LoadBausteine(AStandard: TStandardType; const ACatalogVersion: string): TArray<TBaustein>; virtual; abstract;
    function LoadRequirements(ABausteinDbId: Integer): TArray<TRequirement>; virtual; abstract;
    function LoadAllRequirements(AStandard: TStandardType; const ACatalogVersion: string): TArray<TRequirement>; virtual; abstract;
    function GetLastError: string; virtual; abstract;
    property LastError: string read GetLastError;
  end;

  TProjectRepositoryBase = class
  public
    function LoadProjects: TArray<TProject>; virtual; abstract;
    function CreateProject(const AName, ADescription, ACatalogVersion: string): TProject; virtual; abstract;
    function UpdateProject(const AProject: TProject): Boolean; virtual; abstract;
    function DeleteProject(AProjectId: Integer): Boolean; virtual; abstract;
    function LoadAssessment(AProjectId, ATargetObjectId, ARequirementDbId: Integer): TRequirementAssessment; virtual; abstract;
    function SaveAssessment(const AAssessment: TRequirementAssessment): TAssessmentSaveResult; virtual; abstract;
    function GetLastError: string; virtual; abstract;
    property LastError: string read GetLastError;
  end;

  TTargetObjectRepositoryBase = class
  public
    function LoadTargetObjects(AProjectId: Integer): TArray<TTargetObject>; virtual; abstract;
    function CreateTargetObject(const ATargetObject: TTargetObject): TTargetObject; virtual; abstract;
    function UpdateTargetObject(const ATargetObject: TTargetObject): Boolean; virtual; abstract;
    function DeleteTargetObject(ATargetObjectId: Integer): Boolean; virtual; abstract;
    function CreateDefaultScope(AProjectId: Integer; const AProjectName: string): TTargetObject; virtual; abstract;
    function LoadApplicabilityMap(AProjectId, ATargetObjectId: Integer): TDictionary<Integer, TApplicabilityStatus>; virtual; abstract;
    function Applicability(AProjectId, ATargetObjectId, ABausteinDbId: Integer): TApplicabilityStatus; virtual; abstract;
    function SaveApplicability(const AApplicability: TBausteinApplicability): Boolean; virtual; abstract;
    function GetLastError: string; virtual; abstract;
    property LastError: string read GetLastError;
  end;

  TMeasureRepositoryBase = class
  public
    function LoadMeasures(AProjectId, ATargetObjectId, ARequirementDbId: Integer): TArray<TMeasure>; virtual; abstract;
    function MeasureCounts(AProjectId, ATargetObjectId: Integer): TDictionary<Integer, Integer>; virtual; abstract;
    function CreateMeasure(const AMeasure: TMeasure): TMeasure; virtual; abstract;
    function UpdateMeasure(const AMeasure: TMeasure): TMeasureSaveResult; virtual; abstract;
    function DeleteMeasure(AMeasureId: Integer): Boolean; virtual; abstract;
    function GetLastError: string; virtual; abstract;
    property LastError: string read GetLastError;
  end;

implementation

end.
