unit Entities;

interface

type

  TPerson = class
  const
    DATETIME_FORMAT = 'dd/mm/yyyy';
  strict private
    FFirstName: string;
    FLastName: string;
    FBirthDay: TDateTime;
    function GetAge: LongWord;
  public
    constructor Create(const FirstName: string; LastName: string;
      const BirthDay: TDateTime); overload;
    constructor Create(const FirstName: string; LastName: string;
      const BirthDay: string); overload;
    property FirstName: string read FFirstName;
    property LastName: string read FLastName;
    property BirthDay: TDateTime read FBirthDay;
    property Age: LongWord read GetAge;
  end;

implementation
uses SysUtils;

{ TPerson }

constructor TPerson.Create(const FirstName: string; LastName: string;
  const BirthDay: TDateTime);
begin
  FFirstName := FirstName;
  FLastName := LastName;
  FBirthDay := BirthDay;
end;

constructor TPerson.Create(const FirstName: string; LastName: string;
  const BirthDay: string);
begin
  FFirstName := FirstName;
  FLastName := LastName;

end;

function TPerson.GetAge: LongWord;
begin
  Result := 0;
end;

end.
