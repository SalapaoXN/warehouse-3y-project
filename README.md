# Silent Sting Data Warehouse

โปรเจกต์ตัวอย่างคลังข้อมูล PostgreSQL + dbt + Airflow + Metabase สำหรับวิเคราะห์ข้อมูลผู้ป่วยจากเหตุสัตว์กัด/ต่อย ใช้เพื่อการเรียนและวิเคราะห์ภาพรวมเท่านั้น ไม่ใช่เพื่อการรักษา

## ต้องมี
- Git, Docker Desktop และ Docker Compose
- Python 3.10+ เฉพาะกรณีเปลี่ยนชุดข้อมูลเอง

## เริ่มตั้งแต่ Clone จนดูผล
ทำใน PowerShell โดยเปิด Docker Desktop ไว้

1. Clone โปรเจกต์:
   ```powershell
   git clone https://github.com/SalapaoXN/warehouse-3y-project.git
   cd warehouse-3y-project
   ```
   มีชุดข้อมูลตัวอย่าง `data/raw_triage_case_rows.csv.gz` ใน repo แล้ว ไม่ต้องหา CSV จาก Downloads

2. เปิด PostgreSQL, dbt, Airflow และ Metabase:
   ```powershell
   docker compose up -d --build
   docker compose ps
   ```
   รอจน service แสดงสถานะพร้อมใช้งาน; ครั้งแรกอาจใช้เวลาสร้าง image

3. เข้า Airflow ที่ [http://localhost:8080](http://localhost:8080) ใช้ `admin`; ดูรหัสผ่านครั้งแรกด้วย:
   ```powershell
   docker compose logs airflow
   ```
   ใน Airflow เลือก DAG `silent_sting_patient_dw` แล้วกด Trigger DAG; รอ task ทุกตัวเป็นสีเขียว
   DAG จะรอ PostgreSQL → โหลด CSV เข้า `ss_raw` → รัน `dbt build` เพื่อสร้างตารางและทดสอบข้อมูล

4. ตรวจว่ามีตาราง Fact และ Mart:
   ```powershell
   docker compose exec postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "\dt ss_dw.*"'
   docker compose exec postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "\dt ss_mart.*"'
   docker compose exec postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT COUNT(*) FROM ss_dw.fact_bite_triage;"'
   docker compose exec postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT COUNT(*) FROM ss_mart.rpt_bite_triage_monthly_location_source_level;"'
   ```

5. เตรียมบัญชีอ่านข้อมูลให้ Metabase (ทำหลัง DAG สำเร็จ):
   ```powershell
   Get-Content scripts/grant_metabase_readonly.sql | docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
   docker compose exec postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
   ```
   ในหน้าต่าง `psql` รัน `\password metabase_reader` แล้วตั้งรหัสผ่าน จากนั้นรัน `\q` เพื่อออก

6. ตั้งค่า Metabase ที่ [http://localhost:23000](http://localhost:23000): สร้างบัญชีผู้ดูแล แล้วเพิ่ม PostgreSQL โดยใช้ host `postgres`, port `5432`, database `silent_sting_dw`, user `metabase_reader` และรหัสผ่านที่ตั้งไว้

7. เปิด schema `ss_mart` เพื่อใช้รายงานและทำ Dashboard; เปิด `ss_dw` เมื่อต้องการดู Star Schema โดยตรง คู่มือสร้างกราฟอยู่ที่ [docs/metabase.md](docs/metabase.md)

## รัน Pipeline โดยไม่กด DAG
ใช้แทนขั้นตอน Trigger ใน Airflow ได้ หลัง `docker compose up` สำเร็จ:
```powershell
docker compose exec airflow python /opt/airflow/project/scripts/load_raw.py
docker compose exec dbt dbt build
```
คำสั่ง `dbt build` สร้าง models และรัน tests; ต้องสำเร็จก่อนใช้ข้อมูลใน Metabase

## ใช้ CSV ชุดอื่น (ไม่บังคับ)
เตรียมไฟล์ที่มีคอลัมน์ตามที่สคริปต์กำหนด แล้วรัน:
```powershell
python scripts/prepare_seed.py --input "C:\Users\ชื่อผู้ใช้\Downloads\silent_sting_triage_data_enriched.csv"
```
สคริปต์สร้าง `data/raw_triage_case_rows.csv` และอัปเดต manifest; loader จะใช้ CSV นี้แทนไฟล์ `.gz`

## หยุด / เริ่มใหม่
```powershell
docker compose down
docker compose up -d
```
`down` เก็บข้อมูลไว้; `docker compose down -v` ลบข้อมูล PostgreSQL และการตั้งค่า/dashboard Metabase ทั้งหมด

## ข้อควรทราบ
- Grain ของ Fact คือหนึ่งแถวต่อ `patient_id`; dbt tests ตรวจ ID ซ้ำและความสอดคล้องของยอด
- ชุดข้อมูลมี `patient_id` และข้อมูลสุขภาพระดับแถว; อย่าแทนที่หรือเผยแพร่ด้วยข้อมูลผู้ป่วยจริง/ข้อมูลที่ไม่มีสิทธิ์เผยแพร่
- ไม่มีตัวหารประชากรและอาจมีวันที่ในอนาคต จึงใช้คำนวณอัตราเสี่ยงหรืออุบัติการณ์ไม่ได้โดยตรง
- Airflow และรหัสผ่านเริ่มต้นเหมาะสำหรับการทดลองในเครื่องเท่านั้น
