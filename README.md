# Silent Sting Data Warehouse

## 1. รันโปรเจกต์ตั้งแต่ต้นจนจบ

### สิ่งที่ต้องมี
- Git, Docker Desktop และ Docker Compose; ใช้ PowerShell ที่โฟลเดอร์โปรเจกต์
- เปิด Docker Desktop ก่อนเริ่ม

### โครงสร้างไฟล์และระบบ
- `docker-compose.yaml` เปิด PostgreSQL, dbt, Airflow, Metabase และตัวสร้างบัญชี Metabase; `Dockerfile.airflow` กับ `requirements-airflow.txt` เตรียม Airflow ให้รัน DAG ได้
- `dags/` เรียงงานรอฐานข้อมูล → โหลดข้อมูล → `dbt build`; `scripts/` เตรียม CSV, โหลดเข้า raw, สร้างบัญชีผู้ดูแล Metabase และให้สิทธิ์อ่านฐานข้อมูล
- `data/` มี CSV mock แบบบีบอัด; `seeds/` เก็บ manifest, จำนวนแถว และ checksum ของไฟล์
- `dbt_project.yml`, `profiles.yml`, `macros/` ตั้งค่า dbt, การเชื่อมต่อ และชื่อ schema
- `models/staging/` แปลงชนิด/ตรวจข้อมูล; `models/intermediate/` แยกข้อมูลผ่านกับ quarantine
- `models/dimensions/` เก็บมิติวัน จังหวัด สัตว์ อาการ และ triage; `models/facts/` เก็บเหตุการณ์ตาม grain หนึ่ง `patient_id` ต่อแถว
- `models/aggregates/` สรุปยอดรายเดือน; `models/reporting/` ทำ Mart รายวัน/เดือน/ไตรมาส, CUBE และรายละเอียดพร้อมอ่านใน Metabase
- `models/schema.yml` และ `tests/` กำหนด/ตรวจคุณภาพข้อมูล; `notebooks/` ใช้ profile CSV; `schema_postgres.sql` เป็นแบบอ้างอิง ไม่ใช่ตัวสร้างตารางหลัก
- ลำดับข้อมูล: `ss_raw` → `ss_stg` → `ss_dw` (Fact/Dimensions) → `ss_mart` (รายงาน)

### Clone และเปิดระบบ
```powershell
git clone https://github.com/SalapaoXN/warehouse-3y-project.git
cd warehouse-3y-project
docker compose up -d --build
docker compose ps
```
มีข้อมูลตัวอย่าง `data/raw_triage_case_rows.csv.gz` ใน repo แล้ว ไม่ต้องโหลดเพิ่ม; รอให้ containers ขึ้น แล้วเปิด Airflow: [http://localhost:8080](http://localhost:8080)
ชื่อผู้ใช้คือ `admin`; Airflow 3 อาจไม่แสดงรหัสใน log ให้อ่านไฟล์รหัสใน container ด้วยคำสั่งนี้ แล้วคัดลอกค่าที่อยู่ถัดจาก `admin` ไปใส่ช่อง Password:
```powershell
docker compose exec airflow sh -c 'cat /opt/airflow/simple_auth_manager_passwords.json.generated'
```

### โหลดข้อมูลและสร้างคลัง
1. ใน Airflow เปิด DAG `silent_sting_patient_dw` แล้วกด **Trigger DAG**
2. รอทุก task เป็นสีเขียว: DAG รอ PostgreSQL → โหลด CSV เข้า `ss_raw` → รัน dbt ใน Airflow container เพื่อสร้าง models และรัน tests; ถ้า Trigger DAG แล้วไม่ต้องสั่ง `dbt build` เอง
3. ตรวจว่ามีตารางและข้อมูลแล้ว โดยรันคำสั่งต่อไปนี้ใน **PowerShell ที่โฟลเดอร์โปรเจกต์** (อย่ารันในหน้าที่ขึ้นต้นด้วย `silent_sting_dw=#`):
```powershell
docker compose exec -T postgres psql -U dw_user -d silent_sting_dw -c "SELECT table_schema, table_name FROM information_schema.tables WHERE table_schema IN ('ss_dw', 'ss_mart') ORDER BY table_schema, table_name;"
docker compose exec -T postgres psql -U dw_user -d silent_sting_dw -c "SELECT COUNT(*) FROM ss_dw.fact_bite_triage;"
docker compose exec -T postgres psql -U dw_user -d silent_sting_dw -c "SELECT COUNT(*) FROM ss_mart.rpt_bite_triage_monthly_location_source_level;"
```
คำสั่งใช้ค่าตั้งต้นใน `docker-compose.yaml` (`dw_user` / `silent_sting_dw`); ถ้าแก้ค่าใน `.env` ให้ใช้ค่าที่ตั้งไว้แทน ถ้าอยู่ใน `psql` แล้ว ให้พิมพ์ `\q` เพื่อกลับ PowerShell ก่อน; คำสั่ง `\dt` ใช้พิมพ์ในหน้าจอ `psql` โดยตรง ไม่ต้องใส่ใน `-c`.

### เข้า Metabase และเชื่อม PostgreSQL
1. รอข้อความ `Created the first Metabase admin: admin@example.com` จากคำสั่ง `docker compose logs metabase_bootstrap` แล้วเปิด [http://localhost:23000](http://localhost:23000) เพื่อเข้าสู่ระบบ:
   - Email: `admin@example.com`
   - Password: `SilentStingDemo2026!`
   - ชื่อผู้ใช้: Admin User
   - อีเมลนี้เป็นชื่อบัญชีสำหรับล็อกอิน ไม่มี inbox จริง; ยังไม่ต้องตั้ง SMTP
   - บัญชีนี้สร้างอัตโนมัติเฉพาะ Metabase ที่ยังไม่เคยตั้งค่า; ถ้ามี volume เดิม ระบบจะไม่เปลี่ยนบัญชีเดิม
   - รหัสนี้เป็นรหัสสาธารณะสำหรับเดโมในเครื่องเท่านั้น; อย่านำไปใช้กับระบบที่เปิดสู่อินเทอร์เน็ต
2. สร้างบัญชีอ่าน PostgreSQL สำหรับให้ Metabase ดูข้อมูล หลัง DAG สำเร็จ:
```powershell
Get-Content scripts/grant_metabase_readonly.sql | docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
docker compose exec postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
```
3. หลังรันบรรทัดที่สอง prompt จะเป็น `silent_sting_dw=#`; ตรงนี้พิมพ์เฉพาะ `\password metabase_reader` แล้ว `\q` เพื่อกลับ PowerShell
4. ใน Metabase เพิ่มฐานข้อมูล PostgreSQL:
   - Host `postgres`, Port `5432`, Database `silent_sting_dw`
   - User `metabase_reader`, Password ที่ตั้งใน psql
   - เลือก schema `ss_mart` และ `ss_dw`; ถ้ายังไม่เห็นให้สั่ง Sync database schema

### ทางเลือกและปิดระบบ
- ไม่ใช้ Airflow (หลังเปิด containers แล้ว) ให้รัน:
  ```powershell
  docker compose exec airflow python /opt/airflow/project/scripts/load_raw.py
  docker compose exec dbt dbt build
  ```
  รันจาก PowerShell ที่โฟลเดอร์โปรเจกต์ ไม่ใช่ในหน้าต่าง psql; ถ้าเห็น `silent_sting_dw=#` ให้ออกด้วย `\q` ก่อน
- ใช้ CSV ชุดอื่น: เตรียมคอลัมน์ตามสคริปต์ แล้วรัน `python scripts/prepare_seed.py --input "C:\Users\ชื่อผู้ใช้\Downloads\silent_sting_triage_data_enriched.csv"`; จากนั้น Trigger DAG ใหม่
- ปิดชั่วคราว: `docker compose down` แล้วเปิดใหม่ด้วย `docker compose up -d`
- ลบข้อมูล PostgreSQL และ Dashboard/การตั้งค่า Metabase: `docker compose down -v`

## 2. ใช้งาน Metabase และตัวอย่าง

### เลือก Mart ตามคำถาม
| อยากดู | Mart ใน `ss_mart` | สรุป/แสดงผล |
| --- | --- | --- |
| แนวโน้มรายเดือนเทียบชนิดสัตว์ | `rpt_bite_triage_monthly_location_source_level` | Sum `patient_count`; Line, X=`arrival_month`, เส้น=`bite_source` |
| จังหวัดที่มีจำนวนสูง | Mart รายเดือน | Sum `patient_count`; Bar, แกน=`location`; เรียงมากไปน้อย |
| แนวโน้มรายวัน | `rpt_bite_triage_daily_location_source_level` | Sum `patient_count`; Line, X=`arrival_date` |
| เปรียบเทียบรายไตรมาส | `rpt_bite_triage_quarterly_location` | Sum `patient_count`; Line, X=`arrival_quarter`, เส้น=`location` |
| ยอดรวมและ subtotal | `rpt_bite_triage_location_source_level_cube` | Table; `is_all_*` ระบุ subtotal |
| ดูรายละเอียดเหตุการณ์ | `rpt_bite_triage_patient_detail` | Table; กรองวันที่ จังหวัด สัตว์ อาการ หรือระดับคัดกรอง; ไม่มี `patient_id` |

### สร้างคำถามและ Dashboard
1. กด **New → Question**, เลือกฐานข้อมูล `silent_sting_dw` → schema `ss_mart` → Mart ที่ต้องการ
2. กด **Summarize → Sum of Patient Count**; เลือก **Group by** ตามมิติในตารางด้านบน
3. กด **Visualization** เลือก Line, Bar หรือ Table; เพิ่ม Filter แล้วกด **Save**
4. สร้าง Dashboard, เพิ่มคำถามที่บันทึกไว้ และเชื่อม Dashboard filter กับ field ชื่อเดียวกันในการ์ด

ใช้ Sum ของ `patient_count` ไม่ใช้ Count of rows เพราะ Mart รวมข้อมูลไว้แล้ว; อย่าเฉลี่ย `avg_*` หรือ `*_share` ซ้ำข้ามกลุ่มโดยตรง เดือนที่ไม่มีแถวจะไม่แสดงเป็นศูนย์; CUBE มีทั้งแถวปกติและ subtotal

## 3. เกี่ยวกับโปรเจกต์

- **เป้าหมาย:** ฝึก Data Warehouse ด้วย PostgreSQL, dbt, Airflow และ Metabase เพื่อดูจำนวนเหตุการณ์ตามเวลา จังหวัด ชนิดสัตว์ และระดับคัดกรอง
- **ผู้ใช้:** นักศึกษาและผู้วางแผนสาธารณสุขที่ต้องการสำรวจภาพรวม; ไม่ใช่ระบบวินิจฉัยหรือใช้รักษา
- **ข้อมูลและ Grain:** ชุดข้อมูล mock จาก Kaggle; โปรเจกต์สมมติ `patient_id` หนึ่งค่าแทนหนึ่งเหตุการณ์ใน snapshot ปัจจุบัน
- **โครงสร้าง:** `ss_raw` เก็บข้อมูลต้นทาง → `ss_stg` เตรียม/ตรวจข้อมูล → `ss_dw` มี Dimensions และ Fact → `ss_mart` มีตารางรายงานพร้อมใช้ใน Metabase
- **เครื่องมือ:** Airflow เป็นตัวเรียก pipeline; dbt สร้างตารางและทดสอบ; Metabase อ่าน `ss_dw`/`ss_mart` ด้วย `metabase_reader`
- **ข้อจำกัด:** โหลด snapshot ทับชุดปัจจุบัน ไม่มีประวัติย้อนหลัง; ไม่มีตัวหารประชากรจึงคำนวณอัตราอุบัติการณ์ไม่ได้; ข้อมูลอาจมีวันที่อนาคต
- ข้อมูลเป็นข้อมูลสุขภาพระดับเหตุการณ์; ใช้เฉพาะชุด mock ที่ได้รับอนุญาต และรหัสผ่านค่าเริ่มต้นเหมาะสำหรับเครื่องทดลองเท่านั้น
