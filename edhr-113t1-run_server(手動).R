rm(list=ls())

# 載入所需套件
library(DBI)
library(odbc)
library(magrittr)
library(dplyr)
library(readxl)
library(stringr)
library(openxlsx)
library(tidyr)
library(reshape2)
library(scales)

#1122 本期資料

data_teacher <- readxl :: read_excel("C:\\edhr-112t2\\112學年度下學期高級中等學校教育人力資源資料庫（國立學校人事）.xlsx", sheet = "教員資料表")
colname <- data_teacher[1, ]
colnames(data_teacher) <- colname
data_teacher <- data_teacher[-1, ]

data_staff   <- readxl :: read_excel("C:\\edhr-112t2\\112學年度下學期高級中等學校教育人力資源資料庫（國立學校人事）.xlsx", sheet = "職員(工)資料表")
colname <- data_staff[1, ]
colnames(data_staff) <- colname
data_staff <- data_staff[-1, ]

data_retire   <- readxl :: read_excel("C:\\edhr-112t2\\112學年度下學期高級中等學校教育人力資源資料庫（國立學校人事）.xlsx", sheet = "離退教職員(工)資料表")
colname <- data_retire[1, ]
colnames(data_retire) <- colname
data_retire <- data_retire[-1, ]



#1121 上期資料

teacher_pre <- readxl :: read_excel("\\\\192.168.110.245\\Plan_edhr\\教育部高級中等學校教育人力資源資料庫建置第7期計畫(1120201_1130731)\\分析報告\\原始資料\\112學年度上學期高級中等學校教育人力資源資料庫（全國學校人事）_原始資料.xlsx", sheet = "教員資料表")
colname <- teacher_pre[1, ]
colnames(teacher_pre) <- colname
teacher_pre <- teacher_pre[-1, ]
teacher_pre <- teacher_pre %>%
  mutate(dta_teacher = "教員資料表")

staff_pre <- readxl :: read_excel("\\\\192.168.110.245\\Plan_edhr\\教育部高級中等學校教育人力資源資料庫建置第7期計畫(1120201_1130731)\\分析報告\\原始資料\\112學年度上學期高級中等學校教育人力資源資料庫（全國學校人事）_原始資料.xlsx", sheet = "職員(工)資料表")
colname <- staff_pre[1, ]
colnames(staff_pre) <- colname
staff_pre <- staff_pre[-1, ]
staff_pre <- staff_pre %>%
  mutate(dta_teacher = "職員(工)資料表")

drev_person_pre <- bind_rows(teacher_pre, staff_pre) %>%
  rename(source = dta_teacher)


# 合併人事資料表 ----------------------------------------------------------------
data_teacher <- data_teacher %>%
  mutate(source = 1)

data_staff <- data_staff %>%
  mutate(source = 2)

drev_person <- bind_rows(data_teacher, data_staff)

drev_person$source  <-
  factor(
    drev_person$source,
    levels = c(1, 2),
    labels = c("教員資料表", "職員(工)資料表")
  )
#這行在更改source的1和2為教員資料表及職員工資料表，levels是排序依據.

#學校科別資料[每學年1月底更新]
source("./edhr-schooltype_112.R")

#更改人事資料表的學校名稱（若學校名單異動，哪幾間學校名稱需簡寫亦要檢視） -------------------------------------------------------------------
organization <- readxl :: read_excel("\\\\192.168.110.245\\Plan_edhr\\教育部高級中等學校教育人力資源資料庫建置第7期計畫(1120201_1130731)\\1122國立學校名單.xlsx") %>% #[每次填報更改]本次填報的學校名單檔案路徑
  select("學校代碼", "學校名稱") %>%
  rename(organization_id = 學校代碼, edu_name2 = 學校名稱)

drev_person <- drev_person %>%
  left_join(organization, by = "organization_id")

# 人事資料表合併學校科別資訊 ----------------------------------------------------------------
drev_person_1 <- data_schtype_wide %>%
  select(organization_id,
         typeC,
         typeD,
         typeM,
         typeH,
         typeV,
         typeJ,
         typeE,
         typeF) %>%
  distinct(organization_id,
           typeC,
           typeD,
           typeM,
           typeH,
           typeV,
           typeJ,
           typeE,
           typeF) %>%
  merge(x = drev_person,
        by = "organization_id",
        all.x = TRUE) %>%
  distinct()

# 人事資料表資料格式修正 ------------------------------------------------------------------
source("./edhr-dataclean_format-personnel.R")

# 資料表合併
source("./edhr-merge.R")

# 需要每個學期重新調整的項目 -----------------------------------------------------------

### flag_person
# flag2、flag3；spe2、spe6。
# 以上檢查項目依最新的學校名單、群科開設狀況而定。相關資訊可上統計處查詢高級中等學校科別資料。
# flag6需檢查各表姓名是否為純中文或純英文，或者是否夾雜其他運算字元、特殊符號。
# flag8需檢查持外來人口統一證號的教職員(工)是否有填其國籍別，又其國籍別是否足以辨認。
# flag9需檢查最高學歷畢業學校國別（一）(schooln1)所填之國籍別是否足以辨認。
# flag_person <- drev_person_1 %>%
#   mutate(err_flag_2 = if_else((organization_id == "011315" | organization_id == "013430" | organization_id == "110409" | organization_id == "193404" | organization_id == "381305" | organization_id == "533402"), 1, 0),
#          err_flag_3 = if_else(organization_id == "110302", 1, 0),
#          err_spe_2  = if_else(typeD == 1 & empunit != "雙語部" & source == "教員資料表", 1, 0),
#          err_spe_6  = if_else(typeJ == 1, 1, 0),
#          err_flag_6 = if_else(name == "吳淑貞-", 1, 0),
#          err_flag_8 = if_else(nation == "外籍", 1, 0),
#          err_flag_9 = 0)
# 目前僅限於人事資料表範圍內的檢查項目暫無需檢查是否擔任「科主任」、「學程主任」，
# 因此在備分的檔案(flag_person)先把這兩個職稱拿掉。若往後有此需要，請再另行處理。
# temp <- seq(from = 18, to = 25 , by = 2)
# for (x in temp){
#   flag_person[grep("$科主任", flag_person[x]), ] <- flag_person %>%
#     slice(grep("$科主任", flag_person[x])) %>%
#     mutate(err_flag_2, recode(err_flag_2, "1 = 0"))
#
#   flag_person[grep("$學程主任", flag_person[x]), ] <- flag_person %>%
#     slice(grep("$學程主任", flag_person[x])) %>%
#     mutate(err_flag_3, recode(err_flag_3, "1 = 0"))
# }

#人事
source("./flag1.R")
source("./flag2.R")
source("./flag3.R")
source("./flag6.R")
source("./flag7.R")
source("./flag8.R")
source("./flag9.R")
source("./flag15.R")
source("./flag16.R")
source("./flag18.R")
source("./flag19.R")
source("./flag20.R")
source("./flag24.R")
source("./flag39.R")
source("./flag45.R")
source("./flag47.R")
source("./flag48.R")
source("./flag49.R")
source("./flag50.R")
source("./flag51.R")
source("./flag52.R")
source("./flag57.R")
source("./flag59.R")
source("./flag62.R")
source("./flag64.R")
source("./flag80.R")
source("./flag82.R")
source("./flag89.R")
source("./flag90.R")
source("./flag94.R")
source("./spe3.R")
source("./spe5.R")
source("./spe6.R")
source("./flag83.R")
source("./flag92.R")
source("./flag84.R")
source("./flag85.R")
source("./flag93.R")
source("./flag86.R")
source("./flag91.R")
source("./flag95.R")
source("./flag96.R")
source("./flag97.R")
source("./flag98.R")
source("./flag99.R")
source("./flag100.R")

# #教務
# source("./flag25.R")
# source("./flag26.R")
# source("./flag29.R")
# source("./flag31.R")
# source("./flag56.R")
# source("./flag58.R")
# source("./flag61.R")
# source("./flag67.R")
# source("./flag68.R")
# source("./flag69.R")
# source("./flag70.R")
# source("./flag74.R")
# source("./flag75.R")
# source("./flag101.R")
# source("./spe4.R")


# 建立合併列印檔 -------------------------------------------------------------------
source("./edhr-check02.R")
#輸出檢核結果excel檔
openxlsx::write.xlsx(check02,
                     file = "\\\\192.168.110.245\\Plan_edhr\\教育部高級中等學校教育人力資源資料庫建置第7期計畫(1120201_1130731)\\檢核語法檔\\R\\自動化資料檢核結果\\edhr-112t2-check_print.xlsx",
                     rowNames = FALSE,
                     overwrite = TRUE)
