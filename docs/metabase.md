# Metabase: dashboard รายงาน Silent Sting

คู่มือนี้ทำตามแนว Lab 8: ใช้ Metabase ดูผล roll-up, drill-down และ CUBE
จาก reporting/aggregate models ที่สร้างด้วย dbt โดยไม่เพิ่ม grain หรือ fact ใหม่

## เปิด Metabase

เปิด Docker Desktop แล้วสั่งจาก root ของโปรเจกต์:

```powershell
docker compose up -d --build postgres dbt airflow metabase
```

รัน DAG `silent_sting_patient_dw` ใน Airflow ให้สำเร็จก่อน เพื่อให้ dbt สร้างตารางใน `ss_mart`
จากนั้นเปิด [http://localhost:23000](http://localhost:23000) แล้วสร้างบัญชีผู้ดูแล Metabase
การตั้งค่า Metabase เก็บใน Docker volume `metabase_data` และยังอยู่หลัง `docker compose down`

## สร้างบัญชีอ่านอย่างเดียวสำหรับ Metabase

อย่าใช้ `dw_user` เชื่อม Metabase เพราะเป็นบัญชีที่ dbt ใช้เขียนข้อมูล ให้รันคำสั่งนี้
หลัง `dbt build` สำเร็จ (คำสั่งใช้ user/database จาก Compose):

```powershell
Get-Content scripts/grant_metabase_readonly.sql | docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
docker compose exec postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
```

ในหน้าต่าง `psql` ที่เปิดขึ้น ให้ตั้งรหัสผ่านแล้วออก:

```text
\password metabase_reader
\q
```

สคริปต์ให้สิทธิ์อ่าน schema `ss_dw` (Fact และ Dimension) กับ `ss_mart` (รายงาน)
และตั้ง default privileges สำหรับตาราง/วิวใหม่ที่สร้างด้วยบัญชีเดียวกับ dbt
ถ้าเปลี่ยน `POSTGRES_USER` ให้ใช้ user นั้นรันคำสั่ง บัญชีนี้อ่านข้อมูล Fact ระดับผู้ป่วยได้ด้วย

## เชื่อม PostgreSQL

ในหน้าเริ่มต้น Metabase เลือก PostgreSQL แล้วกรอก:

| ช่อง | ค่า |
| --- | --- |
| Display name | Silent Sting Warehouse |
| Host | `postgres` |
| Port | `5432` |
| Database name | `silent_sting_dw` (หรือค่า `POSTGRES_DB` ใน `.env`) |
| Username | `metabase_reader` |
| Password | รหัสที่ตั้งด้วย `\password` |

Metabase อยู่ใน Docker network เดียวกับ PostgreSQL จึงใช้ host `postgres` และ port ภายใน `5432`
(ไม่ใช่ port `25433` ที่ใช้เชื่อมจากเครื่อง Windows) หลังบันทึก ให้ sync schema หากยังไม่เห็น `ss_dw` หรือ `ss_mart`

## ดูข้อมูลระดับแถวโดยไม่ต้องตั้ง FK ใน Metabase

เปิด `ss_mart.rpt_bite_triage_patient_detail` เพื่อดูหนึ่งแถวต่อหนึ่ง patient-grain record
ฟิลด์วันที่ จังหวัด แหล่งสัตว์ ตำแหน่งที่ถูกกัด อาการ และระดับคัดกรองถูก join เป็นชื่ออ่านได้แล้ว
จึงไม่ต้องตั้ง `Entity Key`, `Foreign Key` หรือ `Display values` ใน Metabase ทีละเครื่อง
ใช้ `patient_count` เป็นตัวนับ; ตารางนี้ไม่แสดง `patient_id`, surrogate keys หรือ source lineage

## ทำ Dashboard ตาม Lab 8

สร้าง dashboard ชื่อ **Silent Sting: Roll-up and Drill-down** แล้วเพิ่มการ์ดจาก `ss_mart`:

1. **แนวโน้มรายเดือน:** `rpt_bite_triage_monthly_location_source_level`; line chart,
   แกนเวลา `arrival_month`, ค่า `patient_count`, แยกชุดข้อมูลตาม `bite_source`
2. **เปรียบเทียบจังหวัด:** ใช้ตารางรายเดือนเดียวกัน; bar chart, จังหวัด `location`,
   ค่า `patient_count`; เพิ่ม filter `arrival_month`, `bite_source` และ `triage_level_label`
3. **Roll-up รายไตรมาส:** `rpt_bite_triage_quarterly_location`; line chart,
   แกนเวลา `arrival_quarter`, ค่า `patient_count`, breakout ตาม `location`
4. **CUBE/subtotals:** `rpt_bite_triage_location_source_level_cube`; table แสดง
   `location`, `bite_source`, `triage_level`, `patient_count` และ flag `is_all_*`

สำหรับ drill-down ให้เริ่มดูรายไตรมาส แล้วเปิดการ์ดเปรียบเทียบจังหวัด/แหล่งสัตว์/ระดับคัดกรอง
ที่ละเอียดขึ้นจากรายเดือน; ตรวจว่า filter ของ dashboard เชื่อมกับการ์ดที่ใช้ field เดียวกัน

## อยากรู้อะไร ให้เปิด Mart ไหน

| คำถาม | ตารางใน `ss_mart` | ค่าที่ใช้ | วิธีแสดงผล |
| --- | --- | --- | --- |
| จำนวนผู้ป่วยเปลี่ยนตามเดือนและชนิดสัตว์อย่างไร | `rpt_bite_triage_monthly_location_source_level` | Sum of `patient_count` | Line; แกน X = `arrival_month`; แยกเส้น = `bite_source` |
| จังหวัดใดมีจำนวนมากในช่วงที่เลือก | ตารางรายเดือนเดียวกัน | Sum of `patient_count` | Bar; แกน = `location`; เรียงจากค่ามากไปน้อย |
| จำนวนรายวันเป็นอย่างไร | `rpt_bite_triage_daily_location_source_level` | Sum of `patient_count` | Line; แกน X = `arrival_date`; ใช้ filter จังหวัด/ชนิดสัตว์ได้ |
| เปรียบเทียบรายไตรมาส | `rpt_bite_triage_quarterly_location` | Sum of `patient_count` | Line; แกน X = `arrival_quarter`; แยกเส้น = `location` หรือ `bite_source` |
| ดูยอดรวมและ subtotal หลายมิติ | `rpt_bite_triage_location_source_level_cube` | `patient_count` | Table; ใช้ `is_all_locations`, `is_all_bite_sources`, `is_all_triage_levels` แยกแถว ALL |
| ดูรายละเอียดหนึ่งแถวต่อหนึ่งเหตุการณ์ตามสมมติฐาน patient ID | `rpt_bite_triage_patient_detail` | `patient_count` | Table; ใช้ค้นหรือกรองวันที่ จังหวัด สัตว์ อาการ และระดับคัดกรอง |

## วิธีสร้างคำถามใน Metabase

1. กด **New → Question → Table**, เลือกฐานข้อมูล `silent_sting_dw` แล้วเลือก schema `ss_mart`
2. เลือกตารางตามคำถามจากตารางด้านบน
3. กด **Summarize**; เลือก **Sum of Patient Count** (อย่าเลือก Count of rows เพราะ Mart มีการรวมข้อมูลไว้แล้ว)
4. ใน **Group by** เลือกมิติ เช่น `Arrival Month`, `Location`, `Bite Source` หรือ `Triage Level Label`
5. ถ้าต้องการเทียบหลายชนิดสัตว์ ให้เพิ่ม `Bite Source` ใน Group by แล้วเลือก Visualization เป็น **Line**; ตั้ง `Arrival Month` เป็นแกน X
6. ใช้ **Filter** เลือกช่วงวัน จังหวัด ชนิดสัตว์ หรือระดับคัดกรอง แล้วกด **Save**
7. เพิ่มคำถามลง Dashboard; เพิ่ม Dashboard filter แล้วเชื่อมกับ field ที่ตรงกันในการ์ดแต่ละใบ

### ข้อควรระวังในการอ่านผล

- `patient_count` เป็นจำนวนที่รวมมาแล้ว จึงใช้ **Sum** เมื่อต้องรวมข้ามจังหวัด สัตว์ หรือระดับคัดกรอง
- Mart รายเดือนมีเฉพาะเดือนที่พบข้อมูล ไม่มีแถวเดือนที่เป็นศูนย์; จุดที่หายไปจึงหมายถึงไม่มีแถวข้อมูลใน snapshot ไม่ได้ยืนยันว่าไม่มีเหตุการณ์จริง
- `avg_*` และ `*_share` เป็นค่าเฉลี่ย/สัดส่วน ณ ระดับแถวของ Mart; อย่านำค่าเหล่านี้มาเฉลี่ยซ้ำข้ามจังหวัดหรือกลุ่มโดยตรง เพราะแต่ละกลุ่มมีจำนวนตัวอย่างต่างกัน
- ระดับคัดกรองเป็นรหัสตามข้อมูลต้นทาง โปรเจกต์ไม่ได้สมมติว่าตัวเลขสูงหรือต่ำแปลว่ารุนแรงกว่า
- ช่วงเวลามาจากวันที่มาถึง; ชุดข้อมูลเป็น snapshot และมีวันในอนาคตตามที่ระบุในข้อจำกัดด้านล่าง

## ข้อจำกัดและข้อมูล

- Dashboard นี้แสดงจำนวนเคสและค่าที่สรุปจากข้อมูล ไม่ใช่อัตราอุบัติการณ์ เพราะไม่มีตัวหารประชากร
- ห้ามแชร์ `patient_id`, CSV ต้นทาง หรือบัญชี `dw_user`; ใช้ `metabase_reader` สำหรับการอ่านเท่านั้น
- `docker compose down -v` จะลบทั้งข้อมูล PostgreSQL และการตั้งค่า/dashboard ของ Metabase
- Metabase image ถูก pin version เพื่อให้ชุด Lab ทำซ้ำได้; ไม่ใช่การตั้งค่าสำหรับ production
