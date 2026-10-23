# Silent Sting Data Warehouse

## 1. โครงสร้างและวิธีเริ่มใช้งาน

### โครงสร้างระบบ
- `docker-compose.yaml` เปิด PostgreSQL, dbt, Airflow, Metabase และสร้างบัญชีผู้ดูแล Metabase ครั้งแรก
- `dags/` ควบคุมลำดับโหลดข้อมูลและสั่ง `dbt build`; `scripts/` เตรียม/โหลดข้อมูลและตั้งค่าผู้ใช้
- `data/` เก็บ CSV ตัวอย่างและ manifest/checksum สำหรับตรวจไฟล์ก่อนโหลด; manifest ไม่ถูก seed เข้า PostgreSQL
- `models/staging/` ทำความสะอาด; `models/intermediate/` แยกข้อมูลใช้ได้กับ quarantine
- `models/dimensions/` สร้างมิติ; `models/facts/` สร้าง Fact โดยสมมติหนึ่ง `patient_id` ต่อหนึ่งเหตุการณ์
- `models/aggregates/` และ `models/reporting/` สร้าง Mart พร้อมวิเคราะห์ใน Metabase
- Fact ไม่เก็บ `patient_count=1`, เวลาที่คำนวณซ้ำ หรือ metadata ติดตามไฟล์/รอบรัน; Mart คำนวณยอดเหตุการณ์ด้วย `count(*)`
- `tests/`, `models/schema.yml` ตรวจคุณภาพ; `profiles.yml`, `dbt_project.yml`, `macros/` ตั้งค่า dbt
- ลำดับข้อมูล: `ss_raw` → `ss_stg` → `ss_dw` (Fact/Dimensions) → `ss_mart` (ตารางวิเคราะห์)

### สิ่งที่ต้องมี
- Git, Docker Desktop และ Docker Compose; คำสั่งด้านล่างใช้ PowerShell ที่โฟลเดอร์โปรเจกต์
- เปิด Docker Desktop ก่อนเริ่ม

### รันตั้งแต่โคลนจนได้คลังข้อมูล
1. โคลนและเปิดทุก service:
   ```powershell
   git clone https://github.com/SalapaoXN/warehouse-3y-project.git
   cd warehouse-3y-project
   docker compose up -d --build
   docker compose ps
   ```
2. มี CSV ตัวอย่าง `data/raw_triage_case_rows.csv.gz` ใน repo แล้ว ไม่ต้องโหลดเพิ่ม
3. เปิด Airflow ที่ [http://localhost:8080](http://localhost:8080); ผู้ใช้ `admin` ดูรหัสผ่านด้วย:
   ```powershell
   docker compose exec airflow sh -c 'cat /opt/airflow/simple_auth_manager_passwords.json.generated'
   ```
4. ใน Airflow เปิด DAG `silent_sting_patient_dw` แล้วกด **Trigger DAG**; รอทุก task เป็นสีเขียว
5. DAG จะรอ PostgreSQL → โหลด CSV เข้า `ss_raw` → รัน `dbt build` เพื่อสร้าง models และตรวจ tests; ไม่ต้องสั่ง `dbt build` ซ้ำ
6. ตรวจตารางและจำนวนแถวใน **PowerShell** (ห้ามรันใน prompt `silent_sting_dw=#`):
   ```powershell
   docker compose exec -T postgres psql -U dw_user -d silent_sting_dw -c "SELECT table_schema, table_name FROM information_schema.tables WHERE table_schema IN ('ss_dw', 'ss_mart') ORDER BY table_schema, table_name;"
   docker compose exec -T postgres psql -U dw_user -d silent_sting_dw -c "SELECT COUNT(*) FROM ss_dw.fact_bite_triage;"
   docker compose exec -T postgres psql -U dw_user -d silent_sting_dw -c "SELECT COUNT(*) FROM ss_mart.rpt_bite_triage_monthly_location_source_level;"
   ```
   ใช้ `dw_user`/`silent_sting_dw` ตามค่าตั้งต้น; ถ้าแก้ `.env` ให้เปลี่ยนค่าในคำสั่งตามนั้น
   ตัวโหลดตรวจจำนวนแถวกับ manifest ในไฟล์ก่อน commit; metadata สำหรับ trace ไม่ถูกเก็บเป็นคอลัมน์ในคลัง

### เข้า Metabase และเพิ่มฐานข้อมูล
1. รอให้บัญชีเริ่มต้นถูกสร้าง ตรวจข้อความด้วย `docker compose logs metabase_bootstrap`
2. เข้า [http://localhost:23000](http://localhost:23000):
   - ชื่อ: **Admin User**; Email: `admin@example.com`
   - Password: `SilentStingDemo2026!`
   - อีเมลเป็นชื่อเข้าระบบ ไม่ต้องมีกล่องเมลจริงหรือ SMTP
   - บัญชีนี้สร้างเมื่อ Metabase ยังไม่เคยตั้งค่า; volume เดิมจะคงบัญชีเดิมไว้
   - รหัสผ่านนี้เป็นรหัสสาธารณะสำหรับเดโมในเครื่องที่เปิดบน localhost เท่านั้น
3. หลัง DAG สำเร็จ สร้างผู้ใช้อ่าน PostgreSQL สำหรับ Metabase:
   ```powershell
   Get-Content scripts/grant_metabase_readonly.sql | docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
   docker compose exec postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
   ```
4. เมื่อเห็น `silent_sting_dw=#` ให้พิมพ์ `\password metabase_reader` แล้ว `\q` เพื่อกลับ PowerShell
5. ใน Metabase เลือกเพิ่มฐานข้อมูล PostgreSQL: Host `postgres`, Port `5432`, Database `silent_sting_dw`
6. ใช้ User `metabase_reader` และรหัสที่ตั้งในข้อ 4; เลือก schema `ss_mart` กับ `ss_dw` แล้ว Sync schema

### ใช้ CSV อื่นและปิดระบบ
- อัปเดตโปรเจกต์เดิม: `git pull` → `docker compose up -d --build` → Trigger DAG ใหม่; จากนั้นใน Metabase สั่ง Sync schema เพื่อซ่อน field เก่าที่ cache ไว้
- ใช้ CSV อื่น: `python scripts/prepare_seed.py --input "C:\Users\ชื่อผู้ใช้\Downloads\silent_sting_triage_data_enriched.csv"` แล้ว Trigger DAG ใหม่
- รันโดยไม่ใช้ Airflow: `docker compose exec airflow python /opt/airflow/project/scripts/load_raw.py` แล้ว `docker compose exec dbt dbt build`
- ปิดชั่วคราว: `docker compose down`; เปิดใหม่ใช้ `docker compose up -d`
- `docker compose down -v` ลบข้อมูล PostgreSQL และการตั้งค่า/บัญชี Metabase ในเครื่องนั้น

## 2. ใช้ Metabase วิเคราะห์อะไรได้บ้าง

1. กด **New → Question** → เลือก `silent_sting_dw` → schema `ss_mart` → เลือก Mart
2. กด **Summarize** แล้วเลือก Sum of `patient_count`; เลือก Group by ตามคำถาม
3. เลือกกราฟ Line, Bar หรือ Table; เพิ่ม Filter แล้ว Save; เพิ่มคำถามที่บันทึกไว้ลง Dashboard ได้

| คำถาม | Mart | แนวทางแสดงผล |
| --- | --- | --- |
| แนวโน้มรายเดือนแยกชนิดสัตว์ | `rpt_bite_triage_monthly_location_source_level` | Sum `patient_count`; Line, X=`arrival_month`, แยกเส้น=`bite_source` |
| จังหวัดที่มียอดสูง | Mart รายเดือน | Sum `patient_count`; Bar, Group by `location`, เรียงมากไปน้อย |
| แนวโน้มรายวัน | `rpt_bite_triage_daily_location_source_level` | Sum `patient_count`; Line, X=`arrival_date` |
| เปรียบเทียบรายไตรมาส | `rpt_bite_triage_quarterly_location` | Sum `patient_count`; Line, X=`arrival_quarter`, แยกเส้น=`location` |
| ดู subtotal | `rpt_bite_triage_location_source_level_cube` | Table; `is_all_*` ระบุ subtotal |
| ดูเหตุการณ์รายคน | `rpt_bite_triage_patient_detail` | Table; กรองวัน จังหวัด สัตว์ อาการ หรือระดับคัดกรอง; ไม่มี `patient_id` |

ใช้ Sum ของ `patient_count` ใน Mart เพราะเป็นยอดรวมของหลายเหตุการณ์; Fact ไม่มี `patient_count` ซ้ำทุกแถวแล้ว อย่าใช้ Count of rows กับ Mart หรือเฉลี่ย `avg_*`/`*_share` ซ้ำข้ามกลุ่ม เดือนที่ไม่มีข้อมูลจะไม่แสดงเป็นศูนย์ และ CUBE มีทั้งแถวปกติกับ subtotal

## 3. เป้าหมายและข้อจำกัด

- ใช้ฝึก Data Warehouse ด้วย PostgreSQL, dbt, Airflow และ Metabase สำหรับดูเหตุการณ์ตามเวลา จังหวัด ชนิดสัตว์ และระดับคัดกรอง
- ผู้ใช้เป้าหมายคือนักศึกษาและผู้วางแผนสาธารณสุข; ไม่ใช่ระบบวินิจฉัยหรือใช้รักษา
- ใช้ชุดข้อมูล mock จาก Kaggle; สมมติ `patient_id` หนึ่งค่าแทนหนึ่งเหตุการณ์ใน snapshot ปัจจุบัน
- โหลด snapshot ทับชุดปัจจุบัน ไม่มีข้อมูลย้อนหลัง; ไม่มีตัวหารประชากร จึงคำนวณอัตราอุบัติการณ์ไม่ได้; ข้อมูลอาจมีวันที่อนาคต
- ใช้ข้อมูล mock ที่ได้รับอนุญาตเท่านั้น; รหัสผ่านเริ่มต้นมีไว้สำหรับเครื่องทดลอง ไม่ควรใช้กับระบบที่เปิดสู่สาธารณะ
