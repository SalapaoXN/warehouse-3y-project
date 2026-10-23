# Silent Sting Data Warehouse

โปรเจกต์คลังข้อมูลตัวอย่างด้วย PostgreSQL, dbt และ Airflow เพื่อวิเคราะห์แนวโน้มผู้ป่วยจากเหตุสัตว์กัดหรือต่อยตามเวลา พื้นที่ แหล่งสัตว์ อาการ และระดับคัดกรอง

> ใช้เพื่อการเรียนและวิเคราะห์ภาพรวม ไม่ใช่ระบบรักษาหรือช่วยตัดสินใจทางคลินิก

## สิ่งที่ต้องมี

- Git, Docker Desktop ที่เปิดใช้งานอยู่ และ Docker Compose
- Python 3.10 ขึ้นไป เฉพาะกรณีต้องการเตรียม/เปลี่ยนไฟล์ CSV เอง

## เริ่มใช้งานบน Windows (PowerShell)

1. Clone repository แล้วเข้าโฟลเดอร์โปรเจกต์:

   ```powershell
   git clone https://github.com/SalapaoXN/warehouse-3y-project.git
   cd warehouse-3y-project
   ```

   มีไฟล์ข้อมูลตัวอย่าง `data/raw_triage_case_rows.csv.gz` อยู่ใน repository แล้ว ไม่ต้องหาไฟล์ต้นฉบับหรือเตรียม CSV ก่อน

2. (ไม่บังคับ) หากต้องการแทนที่ข้อมูลตัวอย่างด้วย CSV ของตนเอง:

   ```powershell
   python scripts/prepare_seed.py --input "C:\Users\ชื่อผู้ใช้\Downloads\silent_sting_triage_data_enriched.csv"
   ```

   สคริปต์สร้าง `data/raw_triage_case_rows.csv` และอัปเดต manifest ใน `seeds/` โดยไม่แก้ไฟล์ต้นฉบับ; CSV ต้องมีชื่อคอลัมน์ตามที่สคริปต์กำหนด ถ้ามีไฟล์นี้ loader จะใช้แทนไฟล์ตัวอย่างที่บีบอัดไว้

3. (ไม่บังคับ) กำหนดค่าฐานข้อมูลเองโดยสร้าง `.env` ที่ root ของโปรเจกต์:

   ```dotenv
   POSTGRES_DB=silent_sting_dw
   POSTGRES_USER=dw_user
   POSTGRES_PASSWORD=change-me
   ```

   ถ้าไม่สร้าง `.env` จะใช้ค่าทดลอง `silent_sting_dw` / `dw_user` / `dw_pass`
   กำหนด `.env` ก่อนเริ่ม Postgres; ไฟล์นี้ถูก ignore แล้ว ห้าม commit หรือส่งรหัสผ่านให้ผู้อื่น

4. สร้างและเปิดบริการ:

   ```powershell
   docker compose up -d --build postgres dbt airflow metabase
   docker compose ps
   ```

   การเปิดครั้งแรกอาจใช้เวลาสร้าง image และเริ่มฐานข้อมูล

## รัน pipeline ด้วย Airflow

1. เปิด [http://localhost:8080](http://localhost:8080)
2. ล็อกอินด้วย user `admin` รหัสผ่านสร้างอัตโนมัติครั้งแรก ดูได้ด้วย:

   ```powershell
   docker compose logs airflow
   ```

3. เลือก DAG `silent_sting_patient_dw` แล้วกด Trigger DAG
4. DAG ทำงานตามลำดับ: รอ PostgreSQL → โหลด CSV เข้า raw → `dbt build`
5. ดูสถานะและ log ของแต่ละ task ในหน้า Airflow; DAG นี้ไม่ได้ตั้งเวลารันอัตโนมัติ

ถ้าต้องการสั่งเองโดยไม่กด DAG (ต้องเปิดบริการตามขั้นตอนก่อน):

```powershell
docker compose exec airflow python /opt/airflow/project/scripts/load_raw.py
docker compose exec dbt dbt build
```

`dbt build` สร้าง models และรัน tests จาก `models/schema.yml` กับ `tests/`

## ดูผลลัพธ์ใน Metabase

ตาราง PostgreSQL อยู่ใน `ss_raw` (ต้นทาง), `ss_stg` (staging), `ss_dw` (dimensions/fact) และ `ss_mart` (สรุป/รายงาน)

หลัง DAG สำเร็จ เปิด [http://localhost:23000](http://localhost:23000) แล้วเชื่อม dashboard กับ `ss_mart`
ทำตาม [คู่มือตั้งค่า Metabase และสร้าง dashboard](docs/metabase.md); ใช้ user อ่านอย่างเดียว `metabase_reader`
ถ้าต้องการดูข้อมูลระดับแถวโดยไม่เห็น FK เป็นตัวเลข ให้เปิด `ss_mart.rpt_bite_triage_patient_detail`
ซึ่ง dbt join ชื่อมิติไว้ให้แล้ว และใช้ `patient_count` สำหรับนับจำนวนแถว/ผู้ป่วย

## หยุดและเริ่มใหม่

```powershell
docker compose down
docker compose up -d
```

`docker compose down` หยุด container แต่เก็บข้อมูลฐานข้อมูลไว้
การลบ volume ด้วย `docker compose down -v` จะลบฐานข้อมูลทั้งหมด

## ข้อควรทราบ

- Grain ของ fact คือหนึ่งแถวต่อ `patient_id` ที่ไม่ซ้ำใน snapshot; หาก ID ซ้ำ tests จะไม่ผ่านและต้องทบทวน grain
- ไฟล์ข้อมูลตัวอย่างใน repository มี `patient_id` และข้อมูลสุขภาพระดับแถว; อย่าแทนที่หรือเผยแพร่ด้วยข้อมูลผู้ป่วยจริงหรือข้อมูลที่ไม่ได้รับอนุญาตให้เผยแพร่สาธารณะ
- ข้อมูลไม่มีตัวหารประชากรและอาจมีวันที่ในอนาคต จึงใช้คำนวณอัตราเสี่ยงหรืออุบัติการณ์ไม่ได้โดยตรง
- Airflow และรหัสผ่านเริ่มต้นใน Compose เหมาะกับการทดลองในเครื่องเท่านั้น
