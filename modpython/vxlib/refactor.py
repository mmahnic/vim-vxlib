#!/usr/bin/python
# vim: set fileencoding=utf-8 sw=3 ts=8 et :vim
#
# @author: Marko Mahnič
# @created: April 2011
#
# Moves functions between Vim files in a larger VimScript project.
# Functions are renamed when moved into/out-of the autoload directory.
#
# The program can also serve as a call-graph calculator.

import os, sys, copy
import re

files = {}

def isAutoload(name):
   return name.startswith("autoload")

def autoloadPrefix(filename):
   if filename.endswith(".vim"):
      filename = filename[:-4]
   n = filename.rfind("autoload/")
   if n < 0: return ""
   return filename[n+9:].replace("/", "#")

def removeFuncPrefix(filename):
   fn = fixPrivateName(filename)
   if fn.startswith("s:"):
      fn = fn[2:]
   n = fn.rfind("#")
   if n >= 0:
      return fn[n:]
   return fn

def fixPrivateName(name):
   if name.upper().startswith("<SID>"):
      name = "s:" + name[5:]
   return name

def funcCallRegex(name):
   name = fixPrivateName(name)
   if name.startswith(r"s:"):
      s = (re.escape("s:")) + "|" + (re.escape("<SID>"))
      name = "(?:" + s + ")" + re.escape(name[2:])
   else:
      name = re.escape(name)
   return name

def vimCmdRegex(vimcmd):
   s = vimcmd.split("|")
   if len(s) != 2: return vimcmd
   echars = [ch for ch in s[1]]
   rxb = "(?:" + "(?:".join(echars)
   rxe = ")?" * len(echars)
   return s[0] + rxb + rxe

rxfunc = re.compile("^" + vimCmdRegex("func|tion!") + "\s+([^(\s]+)\s*(\(.*)$")
rxendf = re.compile("^" + vimCmdRegex("endfu|nction"))

class VimFunc:
   def __init__(self, vimfile, name):
      name = fixPrivateName(name)
      self.name = name
      self.private = name.startswith("s:")
      self.module = name.startswith("$$")
      self.vimfile = vimfile
      self.called_by = []
      self.new_name = None
      self.new_file = None


   def tryAddCaller(self, caller, calledAs):
      if fixPrivateName(calledAs) != self.name:
         return False
      if self.private and self.vimfile != caller.vimfile:
         return False
      try:
         if self.called_by.index(caller) >= 0:
            return True
      except: pass

      self.called_by.append(caller)
      return True


   # Returns true if the function will only be called locally in the new file
   def newHasOnlyLocalCallers(self):
      for c in self.called_by:
         if c.new_file != self.new_file:
            return False

      return True


   def computeNewName(self):
      fn = self.new_file.name
      if not self.private and not isAutoload(fn):
            self.new_name = self.name
            return

      if isAutoload(fn):
         if self.private and self.newHasOnlyLocalCallers():
            self.new_name = self.name
         else:
            self.new_name = "%s#%s" % (autoloadPrefix(fn), removeFuncPrefix(self.name))
      else:
         self.new_name = self.name


   def __repr__(self):
      return "<VimFunc %s>" % self.name


class VimFile:
   def __init__(self, fname):
      self.name = fname
      self.lines = []
      self.functions = []

   def read(self):
      f = open(self.name);
      self.lines = f.readlines()
      f.close()
      self.lines = [l.rstrip() for l in self.lines ]
      # TODO: use only lines until '^finish'

      for l in self.lines:
         mo = rxfunc.match(l)
         if mo != None:
            self.functions.append(VimFunc(self, mo.group(1)))

   def getGlobalFunc(self):
      for func in self.functions:
         if func.name == "$$global":
            return func
      func = VimFunc(self, "$$global")
      self.functions.append(func)
      return func

   def getFunction(self, name):
      for func in self.functions:
         if func.name == fixPrivateName(name):
            return func
      return None


class Distributor:
   def __init__(self):
      self.files = {}
      self.funcLocations = {}
      self.new_files = {}

   def addFile(self, fname):
      vf = VimFile(fname)
      vf.read()
      self.files[fname] = vf

   def getFunctions(self, name):
      funcs = []
      if name != None:
         name = fixPrivateName(name)
      for fname,vf in self.files.items():
         for func in vf.functions:
            if name == None or func.name == name:
               funcs.append(func)
      return funcs

   def makeCallGraph(self):
      allfuncs = self.getFunctions(None)
      rxnames = [ funcCallRegex(vf.name) for vf in allfuncs ]
      rxnames = "(" + (r"|".join(rxnames)) + ")\s*\("
      self.rxnames = re.compile(rxnames)
      for name,vf in self.files.items():
         filefunc = vf.getGlobalFunc()
         func = filefunc
         for l in vf.lines:
            mo = rxfunc.match(l)
            if mo != None:
               func = vf.getFunction(mo.group(1)) # TODO: push
               if func == None:
                  print "Failed", mo.group(1)
               continue
            mo = rxendf.match(l)
            if mo != None:
               func = filefunc # TODO: pop
               continue
            for mo in self.rxnames.finditer(l):
               call_name = mo.group(1)
               flist = self.getFunctions(call_name)
               found = False
               for called in flist:
                  found = found or called.tryAddCaller(func, call_name)

      if 0:
         for f in self.getFunctions(None):
            print f.name, len(f.called_by)

   def getOutputFile(self, fname):
      if not fname in self.new_files:
         self.new_files[fname] = VimFile(fname)

      return self.new_files[fname] 

   def distributeFuncs_Org1(self):
      # Ad hoc distribution
      for f in self.getFunctions(None):
         newf = None
         if f.name == "$$global":
            newf = "new_" + f.vimfile.name
         elif f.private:
            newf = "autoload/org/core.vim"
         else:
            newf = "plugin/org.vim"

         f.new_file = self.getOutputFile(newf)
         f.new_file.functions.append(f)
         f.computeNewName()

      if 1:
         for name,vf in self.new_files.items():
            print "-----", name
            for f in vf.functions:
               print "%30s\t%s" % (f.name, f.new_name)

   def distributeFuncs_Org2(self):
      # Ad hoc distribution
      for f in self.getFunctions(None):
         newf = None
         if f.name == "$$global":
            newf = "new_" + f.vimfile.name
         elif f.private:
            if f.name.endswith("SID"):
               newf = "new_" + f.vimfile.name
            elif f.name.lower().find("random") >= 0:
               newf = "autoload/org/random.vim"
            elif f.name.lower().find("time") >= 0:
               newf = "autoload/org/time.vim"
            elif f.name.lower().find("date") >= 0:
               newf = "autoload/org/time.vim"
            elif f.name.find("Tag") >= 0:
               newf = "autoload/org/tags.vim"
            elif f.name.find("Lorem") >= 0:
               newf = "autoload/org/utils.vim"
            elif f.name.lower().find("agenda") >= 0:
               newf = "autoload/org/agenda.vim"
            elif f.name.lower().find("export") >= 0:
               newf = "autoload/org/export.vim"
            elif f.name.lower().find("2pdf") >= 0:
               newf = "autoload/org/export.vim"
            else:
               newf = "autoload/org/core.vim"
         else:
            newf = "plugin/org.vim"

         f.new_file = self.getOutputFile(newf)
         f.new_file.functions.append(f)
         f.computeNewName()

      if 1:
         for name,vf in self.new_files.items():
            print "-----", name
            for f in vf.functions:
               print "%30s\t%s" % (f.name, f.new_name)


   def renameFunctionCalls(self, line):
      def _rename_one(mo):
         name = mo.group(1)
         fns = self.getFunctions(name)
         if len(fns) < 1:
            print "Can't find the function", name
            return name + "("
         if len(fns) == 1:
            return fns[0].new_name + "("

         print "TODO: Multiple choices for", name
         return fns[0].new_name + "("

      line = self.rxnames.sub(_rename_one, line)
      return line


   def copyFunctionLines(self, mo, func, ilines):
      flines = func.new_file.lines
      name = mo.group(1)
      l = "function! %s %s" % (func.new_name, mo.group(2))
      flines.append(l)
      mo = None
      while mo == None:
         l = ilines.next()
         flines.append(self.renameFunctionCalls(l))
         mo = rxendf.match(l)

      flines.append("")

      return ilines


   def copyFunctions(self):
      for vf in self.files.values():
         module = vf.getGlobalFunc()
         ilines = iter(vf.lines)
         for l in ilines:
            mo = rxfunc.match(l)
            if mo != None:
               func = vf.getFunction(mo.group(1)) # TODO: push
               if func == None:
                  print "Failed", mo.group(1)
               ilines = self.copyFunctionLines(mo, func, ilines)
            else:
               module.new_file.lines.append(self.renameFunctionCalls(l))


   def writeNewFiles(self):
      for fname,vf in self.new_files.items():
         fn = fname.replace("/", "_") + ".vx"
         fout = open(fn, "w")
         for l in vf.lines:
            fout.write("%s\n" % l)
         fout.close()


def Test():
   D = Distributor()
   D.addFile("org.vim")
   D.makeCallGraph()
   D.distributeFuncs_Org1()
   D.copyFunctions()
   D.writeNewFiles()
   return

Test()
sys.exit(0)

