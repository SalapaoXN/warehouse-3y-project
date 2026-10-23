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

## ข้อจำกัดและข้อมูล

- Dashboard นี้แสดงจำนวนเคสและค่าที่สรุปจากข้อมูล ไม่ใช่อัตราอุบัติการณ์ เพราะไม่มีตัวหารประชากร
- ห้ามแชร์ `patient_id`, CSV ต้นทาง หรือบัญชี `dw_user`; ใช้ `metabase_reader` สำหรับการอ่านเท่านั้น
- `docker compose down -v` จะลบทั้งข้อมูล PostgreSQL และการตั้งค่า/dashboard ของ Metabase
- Metabase image ถูก pin version เพื่อให้ชุด Lab ทำซ้ำได้; ไม่ใช่การตั้งค่าสำหรับ production
