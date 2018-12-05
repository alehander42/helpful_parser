import strutils, sequtils, sets, pseudo

type
  Context = ref object
    input: string

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

var nameSymbols = toSet('a'..'z') + toSet('0'..'9') + {'_'}
var numberSymbol = toSet('0' .. '9')

proc substrEq(a: string, b: int, c: string): bool =
  if b + c.len >= a.len:
    return false
  else:
    for i, d in c:
      if a[b + i] != d:
        return false
    return true

proc parseLit(a: string, start: int, ctx: Context): (Node, int, bool) =
  if ctx.input.substrEq(start, a):
    return (nil, start + a.len, true)
  else:
    return (nil, start, false)


proc parseProgram(start: int, ctx: Context): (Node, int, bool)
proc parseLeftExpr(start: int, ctx: Context): (Node, int, bool)
proc parseNumber(start: int, ctx: Context): (Node, int, bool)
proc parseCallArgs(start: int, ctx: Context): (Node, int, bool)
proc parseTopLevel(start: int, ctx: Context): (Node, int, bool)
proc parseExpr(start: int, ctx: Context): (Node, int, bool)
proc parseRightCall(start: int, ctx: Context): (Node, int, bool)
proc parseArgs(start: int, ctx: Context): (Node, int, bool)
proc parseFunctionDef(start: int, ctx: Context): (Node, int, bool)
proc parseRightExpr(start: int, ctx: Context): (Node, int, bool)
proc parseLocal0(start: int, ctx: Context): (seq[Node], int, bool)
proc parseCode(start: int, ctx: Context): (Node, int, bool)
proc parseName(start: int, ctx: Context): (Node, int, bool)

proc parseProgram(start: int, ctx: Context): (Node, int, bool) =
  var children: seq[Node]
  var i = start
  var success = true
  
  var i0 = i
  var child0: Node
  var success0 = false
  
  var i1 = i
  var child1: Node
  var success1 = false
  
  while true:

    (child0, i0, success0) = parseToplevel(i, ctx)
    if success0:
    
      (child1, i1, success1) = parseNl(i0, ctx)
      if success1:
      
        children.add(child0)

        i = i1

      else:
        break
    else:
      break

  result = (Program.init(children), i, success)



proc parseLeftExpr(start: int, ctx: Context): (Node, int, bool) =
  result = parseName(start, ctx)
  if not result[2]:
    result = parseNumber(start, ctx)



proc parseNumber(start: int, ctx: Context): (Node, int, bool) =
  let sub = ctx.input.substr(start, numberSymbols)
  
  if sub.len == 0:
  (sub, start, false)
  else:
  (sub, start + sub.len, true)
  



proc parseCallArgs(start: int, ctx: Context): (Node, int, bool) =
  var children: seq[Node]
  var i = start
  var success = true
  
  var i0 = i
  var child0: Node
  var success0 = false
  
  var i1 = i
  var child1: Node
  var success1 = false
  
  var i2 = i
  var child2: Node
  var success2 = false
  
  var i3 = i
  var child3: Node
  var success3 = false
  
  while true:

    (child0, i0, success0) = parseExpr(i, ctx)
    if success0:
    
      children.add(child0)

      i = i0

      (child1, i1, success1) = parseWs(i0, ctx)
      if success1:
      
        (child2, i2, success2) = parseLit(",", i1, ctx)
        if success2:
        
          (child3, i3, success3) = parseWs(i2, ctx)
          if success3:
          
          else:
            break
        else:
          break
      else:
        break
    else:
      break

  result = (CallArgs.init(children), i, success)



proc parseTopLevel(start: int, ctx: Context): (Node, int, bool) =
  result = parseFunctionDef(start, ctx)
  if not result[2]:
    result = parseExpr(start, ctx)



proc parseExpr(start: int, ctx: Context): (Node, int, bool) =



proc parseRightCall(start: int, ctx: Context): (Node, int, bool) =
  var children: seq[Node]
  var child: Node
  var i = start
  var success = false
  var localChildren: seq[Node]
  
  (child, i, success) = parseLit("(", i, ctx)
  if not success:
  
    return (nil, start, false)
  if not child.isNil: children.add(child)
  (child, i, success) = parseCallArgs(i, ctx)
  if not success:
  
    return (nil, start, false)
  if not child.isNil: children.add(child)
  (child, i, success) = parseLit(")", i, ctx)
  if not success:
  
    return (nil, start, false)
  if not child.isNil: children.add(child)
result = (RightCall.init(children), i, true)


proc parseArgs(start: int, ctx: Context): (Node, int, bool) =
  var children: seq[Node]
  var i = start
  var success = true
  
  var i0 = i
  var child0: Node
  var success0 = false
  
  var i1 = i
  var child1: Node
  var success1 = false
  
  var i2 = i
  var child2: Node
  var success2 = false
  
  var i3 = i
  var child3: Node
  var success3 = false
  
  while true:

    (child0, i0, success0) = parseName(i, ctx)
    if success0:
    
      children.add(child0)

      i = i0

      (child1, i1, success1) = parseWs(i0, ctx)
      if success1:
      
        (child2, i2, success2) = parseLit(",", i1, ctx)
        if success2:
        
          (child3, i3, success3) = parseWs(i2, ctx)
          if success3:
          
          else:
            break
        else:
          break
      else:
        break
    else:
      break

  result = (Args.init(children), i, success)



proc parseFunctionDef(start: int, ctx: Context): (Node, int, bool) =
  var children: seq[Node]
  var child: Node
  var i = start
  var success = false
  var localChildren: seq[Node]
  
  (child, i, success) = parseName(i, ctx)
  if not success:
  
    return (nil, start, false)
  if not child.isNil: children.add(child)
  (child, i, success) = parseLit("(", i, ctx)
  if not success:
  
    return (nil, start, false)
  if not child.isNil: children.add(child)
  (child, i, success) = parseArgs(i, ctx)
  if not success:
  
    return (nil, start, false)
  if not child.isNil: children.add(child)
  (child, i, success) = parseLit("):", i, ctx)
  if not success:
  
    return (nil, start, false)
  if not child.isNil: children.add(child)
  (child, i, success) = parseCode(i, ctx)
  if not success:
  
    return (nil, start, false)
  if not child.isNil: children.add(child)
result = (FunctionDef.init(children), i, true)


proc parseRightExpr(start: int, ctx: Context): (Node, int, bool) =
  result = parseRightCall(start, ctx)
  if not result[2]:
    result = parseNothing(start, ctx)



proc parseLocal0(start: int, ctx: Context): (seq[Node], int, bool) =
  var children: seq[Node]
  var i = start
  var success = true
  
  var i0 = i
  var child0: Node
  var success0 = false
  
  var i1 = i
  var child1: Node
  var success1 = false
  
  while true:

    (child0, i0, success0) = parseExpr(i, ctx)
    if success0:
    
      (child1, i1, success1) = parseNl(i0, ctx)
      if success1:
      
        children.add(child0)

        i = i1

      else:
        break
    else:
      break

  result = (children, i, success)



proc parseCode(start: int, ctx: Context): (Node, int, bool) =
  var children: seq[Node]
  var child: Node
  var i = start
  var success = false
  var localChildren: seq[Node]
  
  (child, i, success) = parseNl(i, ctx)
  if not success:
  
    return (nil, start, false)
  if not child.isNil: children.add(child)
  (child, i, success) = parseIndent(i, ctx)
  if not success:
  
    return (nil, start, false)
  if not child.isNil: children.add(child)
  (localChildren, i, success) = parseLocal0(i, ctx)
  children.add(localChildren)
  
  (child, i, success) = parseDedent(i, ctx)
  if not success:
  
    return (nil, start, false)
  if not child.isNil: children.add(child)
result = (Code.init(children), i, true)


proc parseName(start: int, ctx: Context): (Node, int, bool) =
  let sub = ctx.input.substr(start, nameSymbols)
  
  if sub.len == 0:
  (sub, start, false)
  else:
  (sub, start + sub.len, true)
  



