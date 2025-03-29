cd "D:\HuaweiMoveData\Users\YJY\Desktop\计量经济学\CFPS"


*-------------------------------数据清洗1--------------------------------
* 2014年数据处理
use "D:\HuaweiMoveData\Users\YJY\Desktop\计量经济学\CFPS\2014\Stata14\cfps2014famconf_170630.dta", clear

global year = 2014
global family "fid14"            // 家庭唯一标识
global child_birth "tb1y_a_c"    // 子女出生年份
global mother_birth "tb1y_a_m"   // 母亲出生年份
global child_alive "alive_a14_c" // 子女存活状态

keep $family $child_birth* $mother_birth $child_alive* qa301_a14_m tb4_a14_m
rename (qa301_a14_m tb4_a14_m) (hk14 edu14) // 户口和教育程度

* 筛选适龄母亲（1967-1996年出生）
keep if $mother_birth >= 1967 & $mother_birth <= 1996
tab $mother_birth

* 观察子女数据结构
forval i=1/10 {
	tab $child_alive`i'
	}

* 生成子女存在标记（0=无，1=存在（健在或过世均可））
forval i=1/10 {
    gen child2014y`i' = 0
    replace child2014y`i' = 1 if $child_alive`i' != -8
}

* 计算2014年子女数量
egen childsize2014 = rowtotal(child2014y1-child2014y10)

* 保留单孩家庭
drop if childsize2014 > 1
keep $family childsize2014 edu14 hk14

* 塌缩数据（保留每个家庭的最大值和基础特征）
collapse (max) childsize2014 (first) hk14 edu14, by($family)
save 2014child.dta, replace

*-------------------------------数据清洗2--------------------------------
* 2018年数据处理（逻辑同2014年）
use "D:\HuaweiMoveData\Users\YJY\Desktop\计量经济学\CFPS\2018\Stata14\cfps2018famconf_202008.dta", clear

global year = 2018
global family "fid14"
global child_birth "tb1y_a_c"
global mother_birth "tb1y_a_m"
global child_alive "alive_a18_c"

keep $family $child_birth* $mother_birth $child_alive* tb4_a18_m hukou_a18_m
rename (tb4_a18_m hukou_a18_m) (edu18 hk18)

keep if $mother_birth >= 1967 & $mother_birth <= 1996
tab $mother_birth

forval i=1/10 {
	tab $child_alive`i'
	}
	
forval i=1/10 {
    gen child2018y`i' = 0
    replace child2018y`i' = 1 if $child_alive`i' != -8
}

egen childsize2018 = rowtotal(child2018y1-child2018y10)
keep $family childsize2018 edu18 hk18

collapse (max) childsize2018 (first) hk18 edu18, by($family)
save 2018child.dta, replace

*-------------------------------数据合并1--------------------------------
* 合并2014和2018年数据
use 2018child.dta, clear
merge 1:1 fid14 using 2014child.dta
drop if _merge != 3
drop _merge

* 生成生育状态变量（CFPS数据中有很多错误，必须在此处进行排除，比如这个生育人数怎么会是负的？）
drop if childsize2014 == . | childsize2018 == .
gen birth = childsize2018 - childsize2014
tab birth

* 定义处理组和对照组
gen treat = .
replace treat = 1 if (birth >= 2 & childsize2014 == 0) | (birth >= 1 & childsize2014 == 1) //处理组（也就是受到二孩政策影响并生育子女）
replace treat = 0 if birth == 0 & childsize2014 == childsize2018 //对照组
drop if treat == .

keep fid14 treat edu14 edu18 hk14 hk18
save affect.dta, replace

*-------------------------------经济数据导入-----------------------------
* 2018年经济数据
use "D:\HuaweiMoveData\Users\YJY\Desktop\计量经济学\CFPS\2018\Stata14\cfps2018famecon_202101.dta", clear

global family "fid14"
global basic "food house dress"    // 生存型消费
global enjoy "other daily"         // 享受型消费
global develop "trco med eec"      // 发展型消费

keep $family fincome1 $basic $enjoy $develop pce total_asset finc familysize18
collapse (max) fincome1 $basic $enjoy $develop pce total_asset finc familysize18, by($family)
gen year = 2018
save eco2018.dta, replace

* 2014年经济数据（逻辑同2018年）
use "D:\HuaweiMoveData\Users\YJY\Desktop\计量经济学\CFPS\2014\Stata14\cfps2014famecon_201906.dta", clear

global family "fid14"
global basic "food house dress"
global enjoy "other daily"
global develop "trco med eec"

keep $family fincome1 $basic $enjoy $develop pce total_asset finc fml2014num
collapse (max) fincome1 $basic $enjoy $develop pce total_asset finc fml2014num, by($family)
gen year = 2014

* 合并经济数据
append using eco2018.dta

* 合并处理组标记
merge m:1 fid14 using affect.dta
drop if _merge != 3
drop _merge

* 删除缺失值
bys fid14: gen miss = 1 if missing(daily, dress, eec, food, house, med, other, trco, fincome1, pce, total_asset)
bys fid14: egen maxmiss = max(miss)
drop if maxmiss == 1
drop miss maxmiss

*-------------------------------标签和价格调整---------------------------
* 设置标签
label drop _all

* 户口类型标签
label define hk_label 1 "农业户口" 3 "非农户口" 5 "没有户口" -8 "不适用"
label values hk18 hk_label
label values hk14 hk_label

* 教育程度标签
label define edu_label 1 "文盲/半文盲" 2 "小学" 3 "初中" 4 "高中" 5 "大专" 6 "本科" 7 "硕士" -8 "不适用"
label values edu18 edu_label
label values edu14 edu_label

* 删除人口特征中的无效样本
drop if hk14 == -8 | hk18 == -8 | edu14 == -8 | edu18 == -8

* 价格调整（基于CPI）
merge m:1 year using cpi.dta
replace daily = daily / CPI_家庭日用杂品 * 100
replace dress = dress / CPI_衣着 * 100
replace eec = eec / CPI_教育服务 * 100
replace food = food / CPI_食品 * 100
replace house = house / CPI_居住 * 100
replace med = med / CPI_医疗保健 * 100
replace other = other / CPI * 100
replace trco = trco / CPI_交通通信 * 100
replace fincome1 = fincome1 / CPI * 100
replace pce = pce / CPI * 100
replace finc = finc / CPI * 100
replace total_asset = total_asset / CPI * 100

*-------------------------------关键变量生成-----------------------------
* 消费率和消费结构
gen cr0 = pce / finc
gen cr1 = (food + house + dress) / pce
gen cr2 = (other + daily) / pce
gen cr3 = (trco + med + eec) / pce

* 时间虚拟变量和DID变量
gen post = 0
replace post = 1 if year == 2018
gen did = treat * post

* 统一变量（跨年份）
gen hk = hk14 if year == 2014
replace hk = hk18 if year == 2018
gen edu = edu14 if year == 2014
replace edu = edu18 if year == 2018
gen familysize = fml2014num if year == 2014
replace familysize = familysize18 if year == 2018

* 对数转换
gen lninc = log(fincome1/familysize + 1)
gen lnasset = log(total_asset/familysize + 1)

*-------------------------------数据清理和注释---------------------------
* 删除冗余变量
drop hk18 edu18 hk14 edu14 CPI* fml2014num familysize18 _merge

* 变量排序
order fid14 year cr0 cr1 cr2 cr3 did hk edu lninc lnasset total_asset fincome1 daily dress eec food house med other trco pce familysize

* 删除单观测值家庭
bys fid14: gen obs_count = _N
drop if obs_count < 2
drop obs_count

* 最终注释
label variable fid14       "2014年家庭样本编码"
label variable year        "年份"
label variable cr0         "当年消费率：消费性支出/家庭总收入"
label variable cr1         "生存型消费占比：食品+衣着+居住支出/消费性支出"
label variable cr2         "享受型消费占比：设备+其他支出/消费性支出"
label variable cr3         "发展型消费占比：交通+文教+医疗支出/消费性支出"
label variable did         "处理组*时间虚拟变量（DID核心变量）"
label variable hk          "母亲户口类型（农业/非农）"
label variable edu         "母亲最高学历"
label variable lninc       "对数人均家庭纯收入"
label variable lnasset     "对数人均家庭净资产"
label variable finc        "过去12个月家庭总收入（元）"
label variable fincome1    "家庭纯收入（元）"
label variable daily       "家庭设备及日用品支出（元）"
label variable dress       "衣着鞋帽支出（元）"
label variable eec         "文教娱乐支出（元）"
label variable food        "食品支出（元）"
label variable house       "居住支出（元）"
label variable med         "医疗保健支出（元）"
label variable trco        "交通通讯支出（元）"
label variable pce         "居民消费性支出加总（元）"
label variable other       "其他消费性支出（元）"
label variable total_asset "家庭净资产（元）"
label variable familysize  "家庭人口规模"

sort fid14 year

bys treat post: sum
save final_dataset.dta, replace