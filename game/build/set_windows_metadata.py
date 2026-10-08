"""Rebuild only PE icons and version resources; preserve executable code/imports."""
import sys,pathlib,hashlib,lief,pefile
exe=pathlib.Path(sys.argv[1]);metadata=pathlib.Path(sys.argv[2]);binary=lief.PE.parse(str(exe));donor=lief.PE.parse(str(metadata))
assert binary.header.machine==lief.PE.Header.MACHINE_TYPES.AMD64
code=hashlib.sha256(bytes(binary.get_section('.text').content)).hexdigest()
entry=binary.optional_header.addressof_entrypoint
imports=[(i.name,[(e.name,e.ordinal) for e in i.entries]) for i in binary.imports]
for rid in [3,14,16]:
 binary.resources.delete_child(rid)
 for child in donor.resources.childs:
  if child.id==rid:binary.resources.add_child(child)
config=lief.PE.Builder.config_t();config.resources=True;config.imports=False;config.exports=False;config.relocations=False;config.load_configuration=False
out=exe.with_suffix('.metadata.exe');binary.write(str(out),config)
check=lief.PE.parse(str(out));assert check.optional_header.addressof_entrypoint==entry
assert hashlib.sha256(bytes(check.get_section('.text').content)).hexdigest()==code
assert [(i.name,[(e.name,e.ordinal) for e in i.entries]) for i in check.imports]==imports
p=pefile.PE(str(out));p.OPTIONAL_HEADER.CheckSum=p.generate_checksum();p.write(str(out));out.replace(exe)
p=pefile.PE(str(exe));assert p.FILE_HEADER.Machine==0x8664
print('Windows AMD64 metadata rebuilt; code, entry point and imports unchanged.')
for group in p.FileInfo:
 for record in group:
  if record.Key==b'StringFileInfo':
   for table in record.StringTable:print({k.decode():v.decode() for k,v in table.entries.items()})
print('Runtime imports:', [i.dll.decode() for i in p.DIRECTORY_ENTRY_IMPORT])
