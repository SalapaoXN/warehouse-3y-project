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

## สร้างคำถามและ Dashboard

1. กด **New → Question → Table** แล้วเลือกฐานข้อมูล `silent_sting_dw` และ schema `ss_mart`
2. เลือก Mart ตามคำถามใน README; กด **Summarize → Sum of Patient Count**
3. เลือก **Group by** ตามมิติที่ต้องการ แล้วกด **Visualization** เลือก Line, Bar หรือ Table
4. กด **Save**; สร้าง Dashboard แล้วเพิ่มคำถามที่บันทึกไว้
5. เพิ่ม Dashboard filter และเชื่อมกับ field ชื่อเดียวกันในการ์ด

ใช้ `rpt_bite_triage_patient_detail` เมื่อต้องการดูรายละเอียดแบบตาราง โดยไม่ต้องตั้ง FK ใน Metabase
สำหรับ CUBE ให้เลือก `rpt_bite_triage_location_source_level_cube` และใช้ `is_all_*` ระบุ subtotal (ดูคำอธิบายใน README)

## ข้อจำกัดและข้อมูล

- Dashboard นี้แสดงจำนวนเคสและค่าที่สรุปจากข้อมูล ไม่ใช่อัตราอุบัติการณ์ เพราะไม่มีตัวหารประชากร
- ห้ามแชร์ `patient_id`, CSV ต้นทาง หรือบัญชี `dw_user`; ใช้ `metabase_reader` สำหรับการอ่านเท่านั้น
- `docker compose down -v` จะลบทั้งข้อมูล PostgreSQL และการตั้งค่า/dashboard ของ Metabase
- Metabase image ถูก pin version เพื่อให้ชุด Lab ทำซ้ำได้; ไม่ใช่การตั้งค่าสำหรับ production
