class_name OrtamKur
extends Node3D
## Bölümün aydınlatması ve gökyüzü — tek yerden (Faz 13).
##
## NEDEN TEK YERDEN: Faz 12'ye kadar her bölüm kendi `WorldEnvironment` ve
## `DirectionalLight3D`ini taşıyordu; ikisi elle yazılmış sahnede (bolum1-2),
## dördü üreticide (bolum3-6). Gölge ayarını değiştirmek altı yerde aynı
## değişikliği yapmak demekti ve biri unutulunca fark edilmiyordu — bölümler
## arasında "neden burası daha karanlık?" sorusunun cevabı yoktu.
##
## Bölüme özel olan yalnızca SANAT YÖNÜ: gökyüzü renkleri, sis, güneşin açısı,
## bulut miktarı. Teknik kurulum (gölge kademeleri, sapma, dolgu ışığı, ton
## eşlemesi) burada ve her bölümde aynı.
##
## ANAHTAR–DOLGU (key/fill): tek ışıkla aydınlatılan bir sahnede gölgede kalan
## yüzler TEK renge düşüyor — kutunun iki yüzü de aynı koyu tonda olunca kenar
## kayboluyor. İkinci, gölgesiz ve zayıf bir ışık (gökyüzü renginde, karşı
## taraftan) o yüzleri ayırıyor. Maliyeti gölge üretmediği için düşük.

## Gökyüzü renkleri — bölüm verisinden geliyor.
@export var gok_ust := Color(0.35, 0.45, 0.62)
@export var gok_ufuk := Color(0.72, 0.75, 0.71)
@export var gok_yer := Color(0.35, 0.37, 0.34)
@export_range(0.0, 1.0) var bulut := 0.45
@export var sis_renk := Color(0.702, 0.741, 0.729)
@export var sis := 0.0035
@export var gunes_aci := Vector3(-52, -38, 0)
@export var gunes_gucu := 0.85
@export var gunes_renk := Color(1.0, 0.955, 0.9)
## Dolgu ışığının anahtar ışığa oranı.
@export_range(0.0, 1.0) var dolgu_orani := 0.3

const GOK_GOLGE := preload("res://golgeler/gok.gdshader")

## Gölge kademeleri: yakın kademe DAR tutuluyor. Oyuncu kamerası 5 m arkada;
## keskinliğin gerektiği yer ilk 4 metre. Godot'nun varsayılan bölünmesi
## (0.1/0.2/0.5) bu kadrajda yakın gölgeleri bulanıklaştırıyordu.
const BOLUNME := [0.055, 0.15, 0.38]
## Gölgenin görüldüğü en uzak mesafe. Sis zaten ~80 m'de her şeyi yutuyor;
## daha uzağa gölge üretmek aynı atlası daha geniş alana yayıp yakını bozuyor.
const GOLGE_MESAFE := 65.0

@onready var _dunya: WorldEnvironment = $Dunya
@onready var _gunes: DirectionalLight3D = $Gunes
@onready var _dolgu: DirectionalLight3D = $Dolgu

func _ready() -> void:
	# Ayarlar panelinden gelen kalite değişikliği bu grubu geziyor.
	add_to_group("ortam")
	_gokyuzu_kur()
	_isiklari_kur()
	kalite_uygula()

func _gokyuzu_kur() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = GOK_GOLGE
	mat.set_shader_parameter("ust_renk", gok_ust)
	mat.set_shader_parameter("ufuk_renk", gok_ufuk)
	mat.set_shader_parameter("yer_renk", gok_yer)
	mat.set_shader_parameter("bulut_miktari", bulut)
	# Bulut rengi gökyüzünün üst rengiyle ısınıyor: akşam bölümünde beyaz
	# bulut yanlış duruyor, güneşin rengini almalı.
	mat.set_shader_parameter("bulut_renk", gok_ufuk.lightened(0.35))

	var gok := Sky.new()
	gok.sky_material = mat
	# Gökyüzü ortam ışığının kaynağı; süreç kipi "gerçek zamanlı" olursa
	# bulutlar kıpırdadıkça ışık da titriyor. Bir kez pişirmek yetiyor.
	gok.process_mode = Sky.PROCESS_MODE_REALTIME
	gok.radiance_size = Sky.RADIANCE_SIZE_128

	var ortam := Environment.new()
	ortam.background_mode = Environment.BG_SKY
	ortam.sky = gok
	# Ortam ışığı GÖKYÜZÜNDEN: gölgedeki yüzler düz siyaha değil, gökyüzünün
	# mavisine düşüyor. Sabit bir ortam rengi bunu yapamaz.
	ortam.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	ortam.ambient_light_sky_contribution = 1.0
	ortam.ambient_light_energy = 1.0
	ortam.tonemap_mode = Environment.TONE_MAPPER_AGX
	ortam.tonemap_white = 6.0

	ortam.fog_enabled = true
	ortam.fog_light_color = sis_renk
	ortam.fog_density = sis
	# Havadan perspektif: uzak yüzeyler gökyüzünün rengine kayıyor. Tek renkli
	# sis, arkadaki kayayı öndekiyle aynı tonda boyuyordu; derinlik hissi
	# buradan geliyor.
	ortam.fog_aerial_perspective = 0.4
	# Sis gökyüzüne KARIŞMASIN: gökyüzünün kendi degradesi ve bulutları var,
	# üstüne sis binince ufuk çizgisi düz bir lekeye dönüyor.
	ortam.fog_sky_affect = 0.0

	# Ton düzeltmesi: AGX doygunluğu bilerek düşürüyor (film benzeri), bu
	# stilde biraz geri verilmesi gerekiyor.
	ortam.adjustment_enabled = true
	ortam.adjustment_contrast = 1.04
	ortam.adjustment_saturation = 1.12
	_dunya.environment = ortam

func _isiklari_kur() -> void:
	_gunes.rotation_degrees = gunes_aci
	_gunes.light_energy = gunes_gucu
	_gunes.light_color = gunes_renk
	# Güneş diskini gökyüzü gölgelendiricisine veren ayar bu.
	_gunes.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	_gunes.light_angular_distance = 1.2
	_gunes.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_gunes.directional_shadow_split_1 = BOLUNME[0]
	_gunes.directional_shadow_split_2 = BOLUNME[1]
	_gunes.directional_shadow_split_3 = BOLUNME[2]
	_gunes.directional_shadow_max_distance = GOLGE_MESAFE
	# Kutulardan oluşan bir dünyada gölge sıçraması (acne) yüzey normaline
	# dik bakan geniş düzlemlerde çıkıyor; normal sapması onu kapatıyor.
	_gunes.shadow_normal_bias = 1.4
	_gunes.shadow_bias = 0.04
	_gunes.shadow_blur = 1.1

	# Dolgu: anahtarın tam karşısından değil, 140° yanından. Tam karşıdan
	# gelen dolgu ikinci bir güneş gibi davranıp hacmi düzleştiriyor.
	_dolgu.rotation_degrees = Vector3(-22.0, gunes_aci.y + 140.0, 0.0)
	_dolgu.light_energy = gunes_gucu * dolgu_orani
	_dolgu.light_color = gok_ufuk.lerp(gok_ust, 0.5)
	_dolgu.shadow_enabled = false
	# Gökyüzüne KARIŞMASIN: karışsaydı gökyüzünde ikinci bir güneş belirirdi.
	_dolgu.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY

## Grafik ön ayarını uygular. `Ayarlar.grafik`: 0 düşük, 1 orta, 2 yüksek.
func kalite_uygula() -> void:
	var kalite: int = Ayarlar.grafik
	_gunes.shadow_enabled = kalite >= 1
	_dolgu.visible = kalite >= 1
	var ortam := _dunya.environment
	if ortam == null:
		return
	# Parlama (glow) düşük kalitede kapalı: Compatibility yolunda bedeli
	# ölçülebilir ve oyunun okunabilirliğine katkısı süs düzeyinde.
	ortam.glow_enabled = kalite >= 2
	ortam.glow_intensity = 0.32
	ortam.glow_bloom = 0.06
	ortam.glow_hdr_threshold = 1.05
	# SSAO yalnızca Forward+ (masaüstü) yolunda var; web'de sessizce yok
	# sayılıyor. Yüksek kalitede açılıyor, bütçesi masaüstünde ölçüldü.
	ortam.ssao_enabled = kalite >= 2
	ortam.ssao_radius = 0.7
	ortam.ssao_intensity = 1.6
