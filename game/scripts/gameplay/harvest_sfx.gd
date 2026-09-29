extends RefCounted
## Small original synthesized material transients. No imported reference audio.
## Deterministic PCM, SFX bus volume/mute remain owned by AudioManager.
static func make_stream(kind: String) -> AudioStreamWAV:
	var rate:=22050
	var duration:=0.19 if kind=="flora" else (0.26 if kind=="rock" else 0.30)
	var count:=int(rate*duration)
	var bytes:=PackedByteArray()
	bytes.resize(count*2)
	var rng:=RandomNumberGenerator.new()
	rng.seed=1967
	var smooth:=0.0
	for i in range(count):
		var t:=float(i)/rate
		var noise:=rng.randf_range(-1.0,1.0)
		smooth=lerpf(smooth,noise,0.16)
		var value:=0.0
		match kind:
			"rock":
				value=(noise*0.40+sin(TAU*1180*t)*0.18)*exp(-t*32.0)
				if t>0.055:value+=noise*0.20*exp(-(t-0.055)*24.0)
			"wood":
				value=(sin(TAU*185*t)*0.42+sin(TAU*410*t)*0.17+smooth*0.18)*exp(-t*27.0)
				if t>0.07:value+=smooth*0.23*exp(-(t-0.07)*17.0)
			_:
				value=(smooth*0.55+sin(TAU*(950.0-1300.0*t)*t)*0.09)*exp(-t*22.0)
		value*=minf(t/0.002,1.0)*minf((duration-t)/0.015,1.0)
		bytes.encode_s16(i*2,int(clampf(value,-1.0,1.0)*24000.0))
	var stream:=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=rate
	stream.stereo=false
	stream.data=bytes
	return stream
