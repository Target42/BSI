unit GridHelper;

interface

uses
  Vcl.Grids;

procedure EnableGridColumnSizing(AGrid: TStringGrid);

implementation

procedure EnableGridColumnSizing(AGrid: TStringGrid);
begin
  if AGrid = nil then
    Exit;
  AGrid.Options := AGrid.Options + [goColSizing, goThumbTracking];
end;

end.
