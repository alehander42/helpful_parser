# helpful

var source = """
Program   => (TopLevel @nl)*
TopLevel  => FunctionDef / Signature / ComplexitySignature / Expr
FunctionDef => Name "(" Args ")" ":" Code
Signature => join(Type "->")
ComplexitySignature => join(Name _ "->" _) _ "->" _ BigO
Code      => @indent Expr* @dedent
Type      => Name / Index
BigO      => "O" "[" Expr "]"
Index     => Expr "[" Expr "]"
Expr      => LeftExpr RightExpr
LeftExpr  => IfNode / ForRange / ForIn / ReturnNode / Assign / Declaration / InfixOp / Name / Number
RightExpr => RightCall / @nothing
RightCall => "(" CallArgs ")"
RightCall: Call
IfNode    => "if" _ Expr ":" Code
ForRange  => "for" _ Expr _ "in" _ Expr _ "..<" _ Expr ":" Code
indent: 2
"""

import sequtils, strutils, strformat, tables, macros

type
  # Pray
  TermKind* = enum And, Or, Builtin, Name, Many, Nl, Ws, Indent, Dedent, Nothing, Expr, Join, JoinSome Lit

  Term* = ref object
    case kind*: TermKind:
    of Builtin, Name:
      name*: string
    of And, Or, Many, Join, JoinSome:
      children*: seq[Term]
    of Expr:
      left*: Term
      right*: Term
    of Lit:
      text*: string
    of Nothing, Nl, Ws, Indent, Dedent:
      discard

  # RuleKind* = enum Normal, RightExpr, RuleIndent

  # Rule* = object
  #   case kind*: RuleKind
  #   of Normal:
  #     term*: Term
  #   of RightExpr:
  #     other*: string
  #   of RuleIndent:
  #     indent*: int
  #   name*: string

#   TokenKind = enum TName, TBuiltin, TWs, TLiteral, TLeftParen, TRightParen, TMany

#   Token = object
#     kind: TokenKind
#     text: string

  Parser* = object
    rules*:   Table[string, Term]
    indent*:  int
    top*:     string
    mapping*: Table[string, string]
    help*:    seq[string]

  NimGenerator* = object
    functions*: seq[(string, string)]
    filename*:  string
    base*:      string
    local*:     int

macro init(kindValue: untyped, childrenValue: varargs[untyped]): untyped =
  var childrenNode = quote do: @[]
  for value in childrenValue:
    childrenNode[1].add(value)
  result = quote:
    Term(kind: `kindValue`, children: `childrenNode`)

template name(text: string): Term =
  Term(kind: Name, name: text)

proc lit(text: string): Term =
  Term(kind: Lit, text: text)

proc builtin(text: string): Term =
  Term(kind: Builtin, name: text)

var nl = Term(kind: Nl)
var ws = Term(kind: Ws)
var indentTerm = Term(kind: Indent)
var dedentTerm = Term(kind: Dedent)
var nothing = Term(kind: Nothing)

var parser = Parser(
  rules: {
    "Program": Many.init(name"Toplevel", nl),
    "TopLevel": Or.init(
      name"FunctionDef",
      name"Signature",
      name"ComplexityRule",
      name"Expr"),
    "FunctionDef": And.init(
      lit"def ",
      name"Name",
      lit"(",
      name"Args",
      lit"):",
      name"Code"),
    "Expr": Term(kind: Expr),
    "LeftExpr": Or.init(
        name"Declaration",
        name"Assign",
        name"ForRange",
        name"ReturnNode",
        name"Name",
        name"Number"),
    "RightExpr": Or.init(
        name"RightCall",
        name"RightInfix",
        nothing),
    "RightCall": And.init(
      lit"(",
      name"CallArgs",
      lit")"),
    "RightInfix": And.init(
      ws,
      name"Operator",
      ws,
      name"Expr"),
    "CallArgs": Join.init(
      name"Expr",
      ws,
      lit",",
      ws),
    "Code": And.init(
      nl,
      indentTerm,
      Many.init(name"Expr", nl),
      dedentTerm),
    "Args": Join.init(
      name"Name",
      ws,
      lit",",
      ws),
    "Name": builtin"name",
    "Number": builtin"number",
    "Type": Or.init(
      name"Typename",
      name"Index"),
    "Index": And.init(
      name"Typename",
      lit"[",
      name"Expr",
      lit"]"),
    "Signature": JoinSome.init(
      name"Type",
      lit"->"),
    "ComplexityRule": And.init(
      lit"%",
      name"ComplexitySignature"),
    "ComplexitySignature": JoinSome.init(
      name"ComplexityA",
      lit"->"),
    "BigO": And.init(
      lit"O[",
      name"ComplexityExpression",
      lit"]"),
    "BigM": And.init(
      lit"M[",
      name"ComplexityExpression",
      lit"]"),
    "ComplexityA": Or.init(
      name"ComplexityExpression",
      name"BigO",
      name"BigM"),
    "ComplexityExpression": Or.init(
      name"ComplexityInfix",
      name"Name",
      name"Number"),
    "ComplexityInfix": And.init(
      name"Simple",
      ws,
      name"Operator",
      ws,
      name"ComplexityExpression"),
    "Operator": builtin"operator",
    "Simple": Or.init(
      name"Name",
      name"Number"),
    "Declaration": And.init(
      name"DeclarationName",
      ws,
      name"Assign"),
    "DeclarationName": Or.init(
      lit"let",
      lit"var"),
    "Assign": And.init(
      name"Name",
      ws,
      lit"=",
      ws,
      name"Expr"),
    "ForRange": And.init(
      lit"for ",
      ws,
      name"Name",
      ws,
      lit"in ",
      ws,
      name"Expr",
      ws,
      lit"..<",
      ws,
      name"Expr",
      lit":",
      name"Code"),
    "ReturnNode": And.init(
      lit"return ",
      ws,
      name"Expr"),
    "Typename": builtin"typename"
  }.toTable(),
  indent: 2,
  top: "Program",
  help: @["BigO", "BigM", "ReturnNode"],
  mapping: {"RightCall": "Call", "RightInfix": "InfixOp"}.toTable())

using
  parser: Parser
  generator: var NimGenerator
  term: Term

proc generateRule(generator; name: string; term; parser: Parser)

proc indent(text: string, i: int): string =
  text.splitLines.mapIt(repeat(" ", i) & it.strip).join("\n") & "\n"

proc generateHeader(generator; name: string): string =
  let typ = if not name.startsWith("Local"): "Node" else: "seq[Node]"
  result = if name == "number": "# FAITH\n" else: ""
  result.add(&"proc parse{name.capitalizeAscii}(start: int, ctx: Context): ({typ}, int, bool)")

proc generateParse(generator; term: Term, i: string): string =
  result = case term.kind:
    of Name, Builtin:
      term.name & "("
    of Lit:
      &"Lit(\"{term.text}\", "
    of Nothing, Nl, Ws, Indent, Dedent:
      $term.kind & "("
    else:
      raise newException(ValueError, &"can't parse {term.kind}")
  
  result = "parse" & result & &"{i}, ctx)"

proc generateMany(generator; term; name: string, join: bool = false, some: bool = false): string =
  result = (&"""
    log({name})
    var children: seq[Node]
    var i = start
    var success = true
  """
  ).indent(2)

  var head = ""
  var loop = ("while true:").indent(2) & "\n"
  var main = 0
  # in join, we only return the first
  if not join:
    for i, child in term.children:
      if child.kind == Name:
        main = i
        break

  for i, child in term.children:
    head.add((&"""
      var i{i} = i
      var child{i}: Node
      var success{i} = false
      """
      ).indent(2))
    let i1 = if i == 0: &"i{term.children.len - 1}" else: &"i{i - 1}"
    let parse = generator.generateParse(child, i1)
    loop.add((&"""
      (child{i}, i{i}, success{i}) = {parse}
      if success{i}:
      """
      ).indent(i * 2 + 4))
    if not join and i == term.children.len - 1 or join and i == 0:
      loop.add((&"children.add(child{main})").indent(i * 2 + 6))
      loop.add("\n")
      loop.add((&"i = i{i}").indent(i * 2 + 6))
      loop.add("\n")
    else:
      loop.add("discard".indent(i * 2 + 6))
  for i in countdown(term.children.len - 1, 0):
    let child = term.children[i]

    loop.add("else:".indent(i * 2 + 4))
    loop.add("break".indent(i * 2 + 6))

  result.add(head)
  result.add(loop)
  result.add("\n")
  let a = if not name.startsWith("Local"): &"{name}.init(children)" else: "children"
  if some:
    result.add((&"success = children.len > 0").indent(2))
  result.add((&"result = ({a}, i, success)").indent(2))
  result.add((&"finalLog({name})").indent(2))

proc generateOr(generator, term; name: string): string =
  # support lit only
  result = (&"log({name})").indent(2)
  for i, child in term.children:
    var i1 = if i == 0: 2 else: 4
    if i > 0:
      result.add("if not result[2]:".indent(2))
    let parse = generator.generateParse(child, "start")
    result.add((&"result = {parse}").indent(i1))
    if child.kind == Lit:
      result.add((&"result[0] = {name}.init(\"{child.text}\")").indent(i1))  
  result.add((&"finalLog({name})").indent(2))

proc generateAnd(generator, term; name: string, help: bool = false): string =
  result = (&"""
  log({name})
  var children: seq[Node]
  var child: Node
  var i = start
  var success = false
  var localChildren: seq[Node]
  """
  ).indent(2)


  var actual = 0
  for i, child in term.children:
    if child.kind == Name:
      actual += 1
    if child.kind != Many:
      let parse = generator.generateParse(child, "i")
      result.add((&"""
        (child, i, success) = {parse}
        if not success:
        """
        ).indent(2))
      result.add((&"finalLog({name});return (nil, start, false)").indent(4))
      result.add("if not child.isNil: children.add(child)".indent(2))
    else:
      let local = &"Local{generator.local}"
      generator.local += 1
      generator.generateRule(local, child, Parser())
      result.add((&"""
        (localChildren, i, success) = parse{local}(i, ctx)
        children.add(localChildren)
        """
        ).indent(2))

  if actual != 1 or help:
    result.add((&"result = ({name}.init(children), i, true)").indent(2))
  else:
    # only one child and not help, directly it
    result.add(("result = (children[0], i, true)").indent(2))
  result.add((&"finalLog({name})").indent(2))

proc generateBuiltin(generator; term): string =
  result = case term.name:
    of "name":
      "log(name)\nlet sub = ctx.input.substr(start, nameSymbols)\n".indent(2)
    of "number":
      "log(number)\nlet sub = ctx.input.substr(start, numberSymbols)\n".indent(2)
    of "typename":
      "log(typename)\nlet sub = ctx.input.substr(start, typeSymbols)\n".indent(2)
    of "operator":
      "log(operator)\nlet sub = ctx.input.substr(start, operatorSymbols)\n".indent(2)
    else:
      ""
  
  let parse = if term.name == "number": ".parseInt" else: ""
  result.add(&"""
  if sub.len == 0:
    result = (nil, start, false)
  else:
    result = ({term.name.capitalizeAscii}.init(sub{parse}), start + sub.len, true)
  finalLog(name)
  """)
  
proc generateExpr(generator, term; mapping: Table[string, string]): string =
  var a = "case child1.kind:\n"
  for name, realName in mapping:
    a.add((&"of {name}: {realName}.init(children)").indent(12))
  a.add("else: nil".indent(12))
  
  result = (&"""
    log(expr)
    var child0: Node
    var i = start
    var success0 = false
    var child1: Node
    var success1 = false

    (child0, i, success0) = parseLeftExpr(start, ctx)
    if success0:
      (child1, i, success1) = parseRightExpr(i, ctx)
      if success1:
        if child1.isNil:
          result = (child0, i, true)
        else:
          let children = @[child0].concat(child1.children)
          let node = {a}
          result = (node, i, true)
        return
    result = (nil, start, false)
    finalLog(expr)
  """
  ).splitLines.mapIt(if it.len > 2: it[2 .. ^1] else: it).join("\n")

proc generateRule(generator; name: string; term; parser: Parser) =
  var header = ""
  case term.kind:
  of Many, Or, And, Join, JoinSome:
    header = generator.generateHeader(name)
  of Builtin:
    header = generator.generateHeader(term.name)
  of Expr:
    header = generator.generateHeader("Expr")
  else:
    discard

  var code = ""
  case term.kind:
  of Many:
    code = generator.generateMany(term, name)
  of Or:
    code = generator.generateOr(term, name)
  of Builtin:
    code = generator.generateBuiltin(term)
  of Join:
    code = generator.generateMany(term, name, join=true)
  of JoinSome:
    code = generator.generateMany(term, name, join=true, some=true)
  of Expr:
    code = generator.generateExpr(term, parser.mapping)
  of And:
    code = generator.generateAnd(term, name, help=name in parser.help)
  else:
    echo name, term.kind
    discard
  if header.len > 0:
    generator.functions.add((header, code & "\n"))

proc generateParser(generator): string =
  # headers
  for child in generator.functions:
    result.add(child[0] & "\n") 

  result.add("\n")
  # code
  for child in generator.functions:
    result.add(child[0] & " =\n" & child[1] & "\n\n")

proc save(generator) =
  writeFile(generator.filename, generator.base & generator.generateParser)

proc dedent(text: string, i: int): string =
  text.splitLines.mapIt(if it.len < i: it.strip else: it[i .. ^1]).join("\n")

proc generateBase(generator) =
  generator.base = """
    import strutils, sequtils, sets, types, macros

    type
      Context = ref object
        input: string
        depth: int

    proc toSet(a: HSlice[char, char]): set[char] =
      for b in a:
        result.incl(b)

    # similar to substrEq in strutils

    proc substr(a: string, b: int, c: set[char] = {}): string =
      if b >= a.len:
        return ""
      var i = b
      while i < a.len:
        let d = a[i]
        if d notin c:
          break
        else:
          result.add(d)
        i += 1

    var nameSymbols = toSet('a'..'z') + {'_'}
    var numberSymbols = toSet('0' .. '9')
    var typeSymbols = toSet('A'..'Z') + toSet('a'..'z') + {'_'}
    var operatorSymbols = {'+', '-', '*', '^'}

    proc substrEq(a: string, b: int, c: string): bool =
      if b + c.len > a.len:
        return false
      else:
        for i, d in c:
          if a[b + i] != d:
            return false
        echo b, ": ", c, " ", "ok"
        return true

    
    macro log(name: untyped): untyped =
      let e = newLit($name)
      quote:
        echo repeat("  ", ctx.depth), "visit: ", start, " ", `e`
        ctx.depth += 1

    macro finalLog(name: untyped): untyped =
      let e = newLit($name)
      quote:
        ctx.depth -= 1
    
    proc parseLit(a: string, start: int, ctx: Context): (Node, int, bool) =
      log(lit)
      if ctx.input.substrEq(start, a):
        result = (nil, start + a.len, true)
      else:
        result = (nil, start, false)
      finalLog(lit)

    proc parseSet(a: set[char], start: int, ctx: Context): (Node, int, bool) =
      log(set)
      let parsed = substr(ctx.input, start, a)
      result = (nil, start + parsed.len, true)
      finalLog(set)

    proc parseIndent(start: int, ctx: Context): (Node, int, bool) =
      parseLit("###INDENT###", start, ctx)

    proc parseDedent(start: int, ctx: Context): (Node, int, bool) =
      parseLit("###DEDENT###", start, ctx)

    proc parseWs(start: int, ctx: Context): (Node, int, bool) =
      parseSet({' ', '\t'}, start, ctx)

    proc parseNl(start: int, ctx: Context): (Node, int, bool) =
      parseSet({'\L'}, start, ctx)

    proc parseNothing(start: int, ctx: Context): (Node, int, bool) =
      log(nothing)
      result = (nil, start, true)
      finalLog(nothing)

    proc load(input: string, indent: int): string =
      let lines = input.splitLines.mapIt(it.strip(leading=false))
      result = ""
      var current = 0
      for a, line in lines:
        if line.strip.len == 0:
          result.add("\n")
        else:
          var length = substr(line, 0, {' '}).len
          var newIndent = length div indent
          if newIndent > current + 1:
            raise newException(ValueError, "INDENT " & $a)
          elif newIndent == current + 1:
            result.add("###INDENT###" & line[length .. ^1] & "\n")
          elif newIndent == current:
            result.add(line[length .. ^1] & "\n")
          else:
            for b in newIndent ..< current:
              result.add("###DEDENT###\n")
            result.add(line[length .. ^1] & "\n")
          current = newIndent
      if current > 0:
        for b in 0 ..< current:
          result.add("###DEDENT###\n")
  """.dedent(4)



proc generateTop(generator; name: string, indent: int) =
  generator.functions.add(("proc parse*(input: string): Node", &"""
  var i = load(input, {indent})
  echo i
  var ctx = Context(input: i)
  var res = parse{name}(0, ctx)
  if res[2]:
    res[0]
  else:
    echo "error"
    nil
"""
  ))

proc generate(parser; filename: string) =
  var generator = NimGenerator(filename: filename)
  generator.generateBase()
  for name, term in parser.rules:
    generator.generateRule(name, term, parser)
  generator.generateTop(parser.top, parser.indent)
  generator.save()

parser.generate("pseudo2.nim")

# proc lex(source: string): seq[Token] =
#   var i = 0
#   var token = ""
#   var kind: TokenKind
#   var inLiteral = false
#   while i < source.len:
#     var c = source[i]
#     if c.isAlphaNumeric or c in {'_', '@'}:
#       if token.kind == TN
#       token.add(c)

# proc parseRule(parser, source) =
#   let tokens = lex(source)

# proc parseParser(source: string): Parser =
#   result.rules = initTable[string, Rule]()
#   result.indent = 0

#   let lines = source.splitLines
#   for line in lines:
#     result.parseRule(line)


# left:
#   Name('a')
# right:
#   CallArgs:
#     left:
#       Number(2)
#     right:
#       Nothing
#     left:
#       Number(4)
#     right:
#       Nothing

# LeftExpr + RightCall => Call

# Call(
#   @[Name('a'), CallArgs(Number)])

# Number(2)
# Number(4)


# (IfNode / Assign / Name / Number) MaybeCall

# MaybeCall => ("(" CallArgs ")") / ""


# using
#   start: int
#   ctx: Context

# proc parseJoin(start, ctx): (Node, int, bool) =
#   var children: seq[Node]
#   var i = start
#   var success = true
#   var child0: Node
#   var success0 = false
#   var i0 = i
#   var child1: Node
#   var success1 = false
#   var i1 = i
    
#   while true:
#     (child0, i0, success0) = parseTopLevel(i, ctx)
#     if success0:
#       (child1, i1, success1) = parseLit("->", i0, ctx)
#       if success1:
#         children.add(child0)
#         i = i1
#       else:
#         success = true
#         break
#     else:
#       success = false
#       break

#   result = (Program.init(children), i, success)

# proc parseTopLevel(start, ctx): (Node, int, bool) =
#   var child: Node
#   var i = start
#   var success = false
#   (child, i, success) = parseFunctionDef(start, ctx)
#   if not success:
#     (child, i, success) = parseSignature(start, ctx)
#   result = (child, i, success)

# proc parseProgram(start, ctx): (Node, int, bool) =
#   var children: seq[Node]
#   var i = start
#   var child0: Node
#   var success0 = false
#   var i0 = i
#   var child1: Node
#   var success1 = false
#   var i1 = i
    
#   while true:
#     (child0, i0, success0) = parseTopLevel(i, ctx)
#     if success0:
#       (child1, i1, success1) = parseNl(i0, ctx)
#       if success1:
#         children.add(child0)
#         i = i1
#       else:
#         break
#     else:
#       break

#   result = (Program.init(children), i, true)
