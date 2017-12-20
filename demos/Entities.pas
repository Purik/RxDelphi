unit Entities;

interface
uses SysUtils;

type

  MemLeakError = class(Exception);

  TRefObject = class
  public
    constructor Create;
    destructor Destroy; override;
    class threadvar RefCount: Integer;
  end;

  TPerson = class(TRefObject)
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

  TTwit = class(TRefObject)
  strict private
    FText: string;
    FAuthor: string;
  public
    property Author: string read FAuthor;
    property Text: string read FText;
  end;

implementation

{ TPerson }

constructor TPerson.Create(const FirstName: string; LastName: string;
  const BirthDay: TDateTime);
begin
  inherited Create;
  FFirstName := FirstName;
  FLastName := LastName;
  FBirthDay := BirthDay;
end;

constructor TPerson.Create(const FirstName: string; LastName: string;
  const BirthDay: string);
begin
  inherited Create;
  FFirstName := FirstName;
  FLastName := LastName;

end;

function TPerson.GetAge: LongWord;
begin
  Result := 0;
end;

{ TRefObject }

constructor TRefObject.Create;
begin
  AtomicIncrement(RefCount)
end;

destructor TRefObject.Destroy;
begin
  AtomicDecrement(RefCount)
end;

end.
