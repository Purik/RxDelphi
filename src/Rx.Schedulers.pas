unit Rx.Schedulers;

interface
uses Classes, Rx, Generics.Collections;

type

  TCurrentThreadScheduler = class(TInterfacedObject, IScheduler, StdSchedulers.ICurrentThreadScheduler)
  public
    procedure Invoke(Action: IAction);
  end;

  TMainThreadScheduler = class(TInterfacedObject, IScheduler, StdSchedulers.IMainThreadScheduler)
  public
    procedure Invoke(Action: IAction);
  end;

  TAsyncTask = class(TThread)
  type
    TInput = TThreadedQueue<IAction>;
  strict private
    FInput: TInput;
  protected
    procedure Execute; override;
  public
    constructor Create(Input: TInput);
    destructor Destroy; override;
  end;

  TJob = class(TThread)
  strict private
    FAction: IAction;
  protected
    procedure Execute; override;
  public
    constructor Create(Action: IAction);
    destructor Destroy; override;
  end;

  TSeparateThreadScheduler = class(TInterfacedObject, IScheduler, StdSchedulers.ISeparateThreadScheduler)
  strict private
    FTask: TAsyncTask;
    FJobQueue: TAsyncTask.TInput;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Invoke(Action: IAction);
  end;

  TNewThreadScheduler = class(TInterfacedObject, IScheduler, StdSchedulers.INewThreadScheduler)
  strict private
    FJobs: TList<TJob>;
    procedure RefreshJobs;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Invoke(Action: IAction);
  end;

  TThreadPoolScheduler = class(TInterfacedObject, IScheduler, StdSchedulers.IThreadPoolScheduler)
  type
    tArrayOfTasks = array of TAsyncTask;
  strict private
    FTasks: tArrayOfTasks;
    FJobQueue: TAsyncTask.TInput;
  public
    constructor Create(PoolSize: Integer);
    destructor Destroy; override;
    procedure Invoke(Action: IAction);
  end;

implementation


{ TCurrentThreadScheduler }

procedure TCurrentThreadScheduler.Invoke(Action: IAction);
begin
  Action.Emit;
end;

{ TMainThreadScheduler }

procedure TMainThreadScheduler.Invoke(Action: IAction);
begin
  TThread.Synchronize(nil, procedure
    begin
      Action.Emit;
    end
  );
end;

{ TSeparateThreadScheduler }

constructor TSeparateThreadScheduler.Create;
begin
  FJobQueue := TAsyncTask.TInput.Create;
  FTask := TAsyncTask.Create(FJobQueue);
end;

destructor TSeparateThreadScheduler.Destroy;
begin
  FJobQueue.DoShutDown;
  FTask.WaitFor;
  FTask.Free;
  FJobQueue.Free;
  inherited;
end;

procedure TSeparateThreadScheduler.Invoke(Action: IAction);
begin
  FJobQueue.PushItem(Action)
end;

{ TNewThreadScheduler }

constructor TNewThreadScheduler.Create;
begin
  FJobs := TList<TJob>.Create;
end;

destructor TNewThreadScheduler.Destroy;
var
  Job: TJob;
begin
  for Job in FJobs do begin
    Job.WaitFor;
    Job.Free;
  end;
  FJobs.Free;
  inherited;
end;

procedure TNewThreadScheduler.Invoke(Action: IAction);
begin
  RefreshJobs;
  FJobs.Add(TJob.Create(Action))
end;

procedure TNewThreadScheduler.RefreshJobs;
var
  I: Integer;
begin
  for I := FJobs.Count-1 downto 0 do begin
    if FJobs[I].Terminated then begin
      FJobs[I].Free;
      FJobs.Delete(I);
    end;
  end;
end;

{ TThreadPoolScheduler }

constructor TThreadPoolScheduler.Create(PoolSize: Integer);
var
  I: Integer;
begin
  FJobQueue := TAsyncTask.TInput.Create;
  SetLength(FTasks, PoolSize);
  for I := 0 to High(FTasks) do
    FTasks[I] := TAsyncTask.Create(FJobQueue);
end;

destructor TThreadPoolScheduler.Destroy;
var
  I: Integer;
begin
  FJobQueue.DoShutDown;
  for I := 0 to High(FTasks) do begin
    FTasks[I].WaitFor;
    FTasks[I].Free;
  end;
  FJobQueue.Free;
  inherited;
end;

procedure TThreadPoolScheduler.Invoke(Action: IAction);
begin
  FJobQueue.PushItem(Action)
end;

{ TAsyncTask }

constructor TAsyncTask.Create(Input: TInput);
begin
  FInput := Input;
  inherited Create(False);
end;

destructor TAsyncTask.Destroy;
begin

  inherited;
end;

procedure TAsyncTask.Execute;
var
  Action: IAction;
begin
  while not FInput.ShutDown do begin
    Action := FInput.PopItem;
    try
      if Assigned(Action) then
        Action.Emit;
    except
      // raise off
    end;
  end
end;

{ TJob }

constructor TJob.Create(Action: IAction);
begin
  FAction := Action;
  inherited Create(False);
end;

destructor TJob.Destroy;
begin
  FAction := nil;
  inherited;
end;

procedure TJob.Execute;
begin
  FAction.Emit;
end;

end.
