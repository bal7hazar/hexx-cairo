import re

# test_hex.cairo
p = 'crates/hexx/src/tests/test_hex.cairo'
s = open(p).read()
a = s.index('// The oracle: the definition')
b = s.index('#[test]', a)
body = s[a:b]
body = body.replace('fn oracle_distance(dx: i32, dy: i32) -> u32 {', 'fn distance(dx: i32, dy: i32) -> u32 {')
lines = body.split('\n')
# header comments stay above the trait; the function body is indented into the impl
head = []
rest = []
for i, l in enumerate(lines):
    if l.startswith('//'):
        head.append(l)
    else:
        rest = lines[i:]
        break
fn = '\n'.join('    ' + l if l else l for l in rest).rstrip() + '\n'
new = '\n'.join(head) + '\n#[generate_trait]\nimpl OracleImpl of OracleTrait {\n' + fn + '}\n\n'
s = s[:a] + new + s[b:]
s = s.replace('oracle_distance(', 'OracleTrait::distance(')
open(p, 'w').write(s)

# test_conversions.cairo
p = 'crates/hexx/src/tests/test_conversions.cairo'
s = open(p).read()
a = s.index('/// The oracle: `v & 1`')
b = s.index('#[test]', a)
body = s[a:b]
body = body.replace('fn oracle_shove(', 'fn shove(').replace('fn oracle_to_offset(', 'fn to_offset(')
body = body.replace('oracle_shove(', 'Self::shove(') if False else body
body = body.replace('+ oracle_shove(', '+ OffsetOracleTrait::shove(')
body = body.replace('oracle_to_offset(h, mode, orientation)', 'OffsetOracleTrait::to_offset(h, mode, orientation)')
lines = body.split('\n')
head = []
for i, l in enumerate(lines):
    if l.startswith('///'):
        head.append(l)
    else:
        rest = lines[i:]
        break
fn = '\n'.join('    ' + l if l else l for l in rest).rstrip() + '\n'
fn = fn.replace('    fn check(', '    /// Checks `to_offset_coordinates` against the oracle and the round trip on a grid.\n    fn check(')
fn = fn.replace('oracle_to_offset(h, mode, orientation)', 'OffsetOracleTrait::to_offset(h, mode, orientation)')
new = '\n'.join(head) + '\n#[generate_trait]\nimpl OffsetOracleImpl of OffsetOracleTrait {\n' + fn + '}\n\n'
s = s[:a] + new + s[b:]
s = s.replace('    check(Offset', '    OffsetOracleTrait::check(Offset')
open(p, 'w').write(s)
