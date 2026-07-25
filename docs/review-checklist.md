# Team Review Checklist — `checkout-service`

ใช้กับทุก PR ก่อน approve · ข้อไหนไม่เกี่ยวกับ diff ให้ mark `n/a` พร้อมเหตุผลสั้น ๆ

---

## 1. Correctness & Scope

- [ ] diff แก้เฉพาะสิ่งที่ PR description บอก — ไม่มีการแก้ไฟล์ที่ไม่เกี่ยว
- [ ] ไม่มีการแก้ไฟล์ใน `dist/` (เป็น build output ที่ stale — ห้ามแก้มือ)
- [ ] ไม่มี debug leftovers: `console.log`, `.only`, `.skip`, โค้ดที่ comment ทิ้ง
- [ ] ไม่มี secret / token / API key / connection string หลุดใน diff

## 2. Concurrency (จุดที่พังบ่อยที่สุดใน repo นี้)

- [ ] ทุก read-modify-write ที่คร่อม `await` อยู่ภายใน `withLock` — ไม่มี check-then-act ลอย ๆ
- [ ] lock key ถูก namespace ตาม convention: `sku:${sku}` สำหรับ inventory, `idem:${key}` สำหรับ idempotency
- [ ] ไม่มีการ "optimize" `setTimeout(0)` tick ใน `repositories/asyncStore.ts` ออก — latency นั้นตั้งใจใส่ไว้ให้ race reproduce ได้
- [ ] chain tail ของ lock ยังเก็บด้วย `.catch(() => undefined)` (rejection เดียวต้องไม่ poison ผู้รอคิวถัดไป)

## 3. Checkout / Idempotency invariants

- [ ] ลำดับใน `checkout()` ยังคงเดิม: lookup key **ก่อน** ทำงาน → `doCheckout` → บันทึก key **หลัง** สำเร็จเท่านั้น
      (บันทึกก่อนสำเร็จ = attempt ที่ fail จะ retry ไม่ได้ตลอดกาล)
- [ ] คำขอที่มี `Idempotency-Key` เดิม → ได้ order เดิม และ **ไม่** reserve สต็อกซ้ำ
- [ ] rollback ครบ: ถ้า `doCheckout` fail กลางคัน ต้อง `release` ทุก line ที่ reserve ไปแล้วก่อน throw

## 4. Money

- [ ] เงินเป็น **integer cents** ทั้งหมด — ไม่มี float ใน pricing path
- [ ] ปัดเศษด้วย `Math.round` (half-up) ผ่าน helper ใน `lib/money.ts` ไม่ใช่คำนวณเอง
- [ ] discount ถูก clamp ใน `[0, subtotal]`
- [ ] tax คิดบน `subtotal - discount` ด้วย `TAX_BPS` ไม่ใช่ hard-code 0.07

## 5. Architecture & Conventions

- [ ] layering ไปทางเดียว: `routes → services → repositories` — ไม่มี service เรียก route, ไม่มี route แตะ repo ตรง ๆ
- [ ] service export เป็น plain function (`export async function ...`) ไม่ใช่ class
- [ ] repository access `await` ทุกครั้ง
- [ ] เวลา/นาฬิกา inject ผ่าน `Clock` (`lib/clock.ts`) ไม่เรียก `Date.now()` ตรง ๆ ใน business logic
- [ ] ไม่มี module-level singleton ตัวใหม่ที่ไม่มีทาง reset ใน test

## 6. Tests

- [ ] โค้ดใหม่/แก้ มีเทสต์คลุม และเทสต์ fail ได้จริงถ้าถอด fix ออก
- [ ] เทสต์ isolate state ด้วย `repo.seed([...])` ใน `beforeEach`
- [ ] เทสต์ concurrency ใช้ `Promise.all` และ assert **ทั้ง** จำนวนที่สำเร็จ **และ** ว่าสต็อกไม่ติดลบ
- [ ] ❗ ถ้าเทสต์ concurrency แดง → แก้ที่ production code เท่านั้น **ห้ามลดความเข้มของ assertion**

## 7. Gate ก่อน merge

- [ ] `npm run typecheck` เขียว
- [ ] `npm test` เขียวทั้งหมด
- [ ] `npm run build` เขียว
- [ ] PR description อธิบายชัดว่า **ทำอะไร** และ **ทำไม**

---

## รูปแบบผลรีวิว

รายงานเป็น 4 หัวข้อ:

1. **Summary** — diff ทำอะไร ในระดับ 2–3 บรรทัด
2. **Issues found** — ปัญหาที่ต้องแก้ก่อน merge (ระบุ `file:line` + ข้อ checklist ที่ละเมิด)
3. **Suggestions** — ข้อเสนอที่ไม่ block
4. **Checklist results** — ไล่ทีละหมวด: `pass` / `fail` / `n/a` พร้อมเหตุผลสั้น ๆ

ระดับความรุนแรง: **blocker** (ผิด invariant ข้อ 2–4) · **major** (ผิด convention ข้อ 5–6) · **minor** (สไตล์)
