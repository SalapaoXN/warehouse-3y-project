# Silent Sting Data Warehouse

## 1. รันโปรเจกต์ตั้งแต่ต้นจนจบ

### สิ่งที่ต้องมี
- Git, Docker Desktop และ Docker Compose; ใช้ PowerShell ที่โฟลเดอร์โปรเจกต์
- เปิด Docker Desktop ก่อนเริ่ม

### โครงสร้างไฟล์และระบบ
- `docker-compose.yaml` เปิด PostgreSQL, dbt, Airflow และ Metabase; `Dockerfile.airflow` กับ `requirements-airflow.txt` เตรียม Airflow ให้รัน DAG ได้
- `dags/` เรียงงานรอฐานข้อมูล → โหลดข้อมูล → `dbt build`; `scripts/` เตรียม CSV, โหลดเข้า raw และให้สิทธิ์อ่าน Metabase
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
เข้าด้วย user `admin`; ดูรหัสผ่านครั้งแรกด้วย `docker compose logs --tail 100 airflow`

### โหลดข้อมูลและสร้างคลัง
1. ใน Airflow เปิด DAG `silent_sting_patient_dw` แล้วกด **Trigger DAG**
2. รอทุก task เป็นสีเขียว: DAG รอ PostgreSQL → โหลด CSV เข้า `ss_raw` → สั่ง `dbt build` เพื่อสร้าง models และรัน tests
3. ตรวจจำนวนแถว Fact และ Mart:
```powershell
docker compose exec postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT COUNT(*) FROM ss_dw.fact_bite_triage;"'
docker compose exec postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT COUNT(*) FROM ss_mart.rpt_bite_triage_monthly_location_source_level;"'
```

### เชื่อม Metabase กับ PostgreSQL
1. สร้างบัญชีอ่านสำหรับ Metabase หลัง DAG สำเร็จ:
```powershell
Get-Content scripts/grant_metabase_readonly.sql | docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
docker compose exec postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
```
2. ในหน้าต่าง psql ตั้งรหัสแล้วออก: `\password metabase_reader` จากนั้น `\q`; แต่ละเครื่องตั้งรหัสเอง ไม่เก็บใน Git
3. เปิด [http://localhost:23000](http://localhost:23000) สร้างบัญชีผู้ดูแล แล้วเพิ่มฐานข้อมูล PostgreSQL:
   - Host `postgres`, Port `5432`, Database `silent_sting_dw`
   - User `metabase_reader`, Password ที่ตั้งใน psql
   - เลือก schema `ss_mart` และ `ss_dw`; ถ้ายังไม่เห็นให้สั่ง Sync database schema

### ทางเลือกและปิดระบบ
- ไม่ใช้ Airflow: `docker compose exec airflow python /opt/airflow/project/scripts/load_raw.py` แล้ว `docker compose exec dbt dbt build`
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
