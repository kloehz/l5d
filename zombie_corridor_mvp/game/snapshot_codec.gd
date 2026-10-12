class_name MobCodec
extends RefCounted
const RECORD_BYTES = 28
const MAX_RECORDS = 30
static func encode(records: Array) -> PackedByteArray:
	assert(records.size() <= MAX_RECORDS)
	var bytes = PackedByteArray()
	bytes.resize(2+RECORD_BYTES*records.size())
	bytes.encode_u16(0,records.size())
	var offset = 2
	for row in records:
		bytes.encode_u32(offset,row.id)
		bytes.encode_u32(offset+4,row.generation)
		bytes.encode_u32(offset+8,row.revision)
		bytes.encode_u32(offset+12,row.interest_epoch)
		bytes.encode_s16(offset+16,int(round(row.position.x*100)))
		bytes.encode_s16(offset+18,int(round(row.position.z*100)))
		bytes[offset+20] = clampi(row.hp,0,100)
		bytes[offset+21] = row.state
		bytes.encode_s16(offset+22,int(round(row.yaw*1000)))
		bytes.encode_u32(offset+24,row.tick)
		offset += RECORD_BYTES
	return bytes

static func decode(bytes: PackedByteArray) -> Array:
	if bytes.size() < 2 or bytes.size() > 842: return []
	var count = bytes.decode_u16(0)
	if count > MAX_RECORDS or bytes.size() != 2+count*RECORD_BYTES: return []
	var rows = []
	for i in range(count):
		var o = 2+i*RECORD_BYTES
		var x = bytes.decode_s16(o+16)/100.0
		var z = bytes.decode_s16(o+18)/100.0
		if abs(x)>6 or z>1 or z < -181 or bytes[o+21] > 3: return []
		rows.append({"id":bytes.decode_u32(o),"generation":bytes.decode_u32(o+4),"revision":bytes.decode_u32(o+8),"interest_epoch":bytes.decode_u32(o+12),"position":Vector3(x,0,z),"hp":bytes[o+20],"state":bytes[o+21],"yaw":bytes.decode_s16(o+22)/1000.0,"tick":bytes.decode_u32(o+24)})
	return rows
