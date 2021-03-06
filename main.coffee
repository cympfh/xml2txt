fs = require 'fs'
path = require 'path'
cheerio = require 'cheerio'

# parse args
#
opts = require 'opts'
options = [
  {
    short: 't'
    long: 'tags'
    description: 'tags file (.json) to save'
    value: true
    required: true
  }
  {
    short: 'd'
    long: 'doc'
    description: 'document file to analysis'
    value: true
    required: true
  }
  {
    short: 'i'
    long: 'ignore'
    description: 'add a tag as a ignore tag'
    value: true
  }
  {
    short: 'c'
    long: 'content'
    description: 'add a tag as a content tag'
    value: true
  }
  {
    short: 'o'
    long: 'output'
    description: 'output file'
    value: true
  }
  {
    long: 'to'
    description: 'replace [--from] tag with this text'
    value: true
  }
  {
    long: 'from'
    description: 'replace this tag with [--to] text'
    value: true
  }
]
opts.parse options, true

json_path = opts.get('tags')
doc_path = opts.get('doc')
out_path = opts.get('output')

igs = opts.get('ignore')
cts = opts.get('content')

from_tag = opts.get('from')
to_text = opts.get('to')

# load json
#
json_path = path.resolve json_path
if fs.existsSync json_path
  setting = require json_path
else
  setting =
    content: []
    ignore: []
    subst: []

put = (ls, x) ->
  if not (x in ls)
    ls.push x

if igs
  igs.split(',').forEach (ig) ->
    ig = ig.trim()
    put setting.ignore, ig

if cts
  cts.split(',').forEach (ct) ->
    ct = ct.trim()
    put setting.content, ct

if from_tag and to_text
  setting.subst.push
    from: from_tag
    to: to_text

findWithFrom = (tag) ->
  for o in setting.subst
    return o.to if o.from is tag
  return false

fs.writeFileSync json_path, JSON.stringify setting

analysis = (fn, out) ->
  if out
    fs.writeFileSync out, ''
  $ = cheerio.load fs.readFileSync fn, 'utf8'
  cx = 0
  sub = (lst) ->
    I = lst.length
    for elem in lst
      if out and (elem.type is 'text')
        fs.appendFileSync out, elem.data
      if elem.type is 'tag'
        switch
          when elem.name in setting.content
            sub elem.children
          when elem.name in setting.ignore
            undefined
          when findWithFrom elem.name
            if out
              alt = findWithFrom elem.name
              fs.appendFileSync out, alt
          else
            ++cx
            console.warn "<#{elem.name}> is unknown."

  sub $._root.children
  if (cx is 0) and (not out)
    console.warn "#{String.fromCharCode(27)}[32mpassed!#{String.fromCharCode(27)}[m"

  return (cx is 0)

xmlfilep = (path) ->
  return true if path.slice(-4) is '.xml'
  return true if path.slice(-5) is '.html'
  return true if path.slice(-6) is '.xhtml'
  return false

if fs.existsSync doc_path
  if fs.statSync(doc_path).isDirectory()
    bl = true
    fs.readdirSync(doc_path).forEach (item) ->
      fpath = path.join doc_path, item
      opath =
        if out_path
          path.join out_path, item + '.txt'
        else
          false
      if xmlfilep fpath
        console.warn '#',fpath
        re = analysis fpath, opath
        bl = bl and re
    if bl and (not out_path)
      console.warn "#{String.fromCharCode(27)}[34mall passed!#{String.fromCharCode(27)}[m"
  else
    analysis doc_path, out_path
else
  console.warn "#{doc_path} not exist?"

