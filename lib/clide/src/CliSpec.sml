structure CliSpec =
struct
  datatype ty = TInt | TBool | TStr | TPath

  datatype atom =
      Lit of string
    | OptBool of { long: string option, short: string option }
    | OptVal of { long: string option, short: string option, ty: ty, default: string option, allowRepeat: bool }
    | Pos of { name: string, ty: ty, default: string option }

  datatype group =
      Single of atom
    | Alt of atom list

  datatype item =
      Required of group
    | Optional of group

  datatype command = Command of { name: string, items: item list }

  datatype spec = Spec of { prog: string, commands: command list }

  fun tyToString TInt = "INT"
    | tyToString TBool = "BOOL"
    | tyToString TStr = "STR"
    | tyToString TPath = "PATH"
end
