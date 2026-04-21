-- EduCRM Complete Database Schema
-- Paste this entire file into your Supabase SQL Editor and run it to set up the database.

-- 1. Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Create lead_stages table
CREATE TABLE IF NOT EXISTS lead_stages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    color TEXT DEFAULT '#7366FF',
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Create leads table
CREATE TABLE IF NOT EXISTS leads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    phone TEXT,
    phone2 TEXT,
    source TEXT,
    interest TEXT,
    description TEXT,
    priority TEXT DEFAULT 'Warm',
    stage_id UUID REFERENCES lead_stages(id) ON DELETE SET NULL,
    avatar_color TEXT DEFAULT '#7366FF',
    comments_list JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 4. Create teachers table
CREATE TABLE IF NOT EXISTS teachers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    subject TEXT,
    phone TEXT,
    email TEXT,
    percentage INTEGER,
    status TEXT DEFAULT 'Active',
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 5. Create courses table
CREATE TABLE IF NOT EXISTS courses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    category TEXT,
    teacher_id UUID REFERENCES teachers(id) ON DELETE SET NULL,
    price BIGINT,
    status TEXT DEFAULT 'Active',
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 6. Create rooms table
CREATE TABLE IF NOT EXISTS rooms (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    capacity INTEGER,
    type TEXT,
    status TEXT DEFAULT 'Active',
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 7. Create groups table
CREATE TABLE IF NOT EXISTS groups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    course_id UUID REFERENCES courses(id) ON DELETE SET NULL,
    teacher_id UUID REFERENCES teachers(id) ON DELETE SET NULL,
    room TEXT,
    days TEXT[],
    time TEXT,
    status TEXT DEFAULT 'Active',
    students_list UUID[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 8. Create students table
CREATE TABLE IF NOT EXISTS students (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    phone TEXT,
    phone2 TEXT,
    balance BIGINT DEFAULT 0,
    discount BIGINT DEFAULT 0,
    groups UUID[] DEFAULT '{}',
    status TEXT DEFAULT 'Active',
    avatar_color TEXT DEFAULT '#7366FF',
    added_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 9. Create attendance table
CREATE TABLE IF NOT EXISTS attendance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
    student_id UUID REFERENCES students(id) ON DELETE CASCADE,
    lesson_date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'present',
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(student_id, group_id, lesson_date)
);

-- 10. Create payments table
CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID REFERENCES students(id) ON DELETE CASCADE,
    receipt_id TEXT,
    amount BIGINT NOT NULL,
    method TEXT,
    date TIMESTAMPTZ DEFAULT now(),
    status TEXT DEFAULT 'processed',
    comment TEXT,
    month TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 11. Create payment_reminders table
CREATE TABLE IF NOT EXISTS payment_reminders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID REFERENCES students(id) ON DELETE CASCADE,
    group_id UUID REFERENCES groups(id) ON DELETE SET NULL,
    promised_date DATE,
    amount BIGINT,
    notes TEXT,
    status TEXT DEFAULT 'Pending' CHECK (status IN ('Pending', 'Paid', 'Cancelled')),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 12. Create boards table (for tasks)
CREATE TABLE IF NOT EXISTS boards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    color TEXT DEFAULT '#7366FF',
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 13. Create tasks table
CREATE TABLE IF NOT EXISTS tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    board_id UUID REFERENCES boards(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    priority TEXT DEFAULT 'Medium',
    due_date TEXT,
    progress INTEGER DEFAULT 0,
    comments_list JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 14. Create archives table
CREATE TABLE IF NOT EXISTS archives (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type TEXT NOT NULL,
    original_id UUID,
    data JSONB NOT NULL,
    archived_at TIMESTAMPTZ DEFAULT now()
);

-- 15. Create staff table
CREATE TABLE IF NOT EXISTS staff (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    role TEXT DEFAULT 'Staff',
    status TEXT DEFAULT 'Active',
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ==========================================
-- OPTIONAL: ENABLE ROW LEVEL SECURITY
-- By default, Supabase requires RLS for API requests. 
-- You can either disable RLS (for testing) or add public policies.
-- Below we enable RLS and allow all authenticated & anon users to read/write.
-- ==========================================

-- Disable RLS or create "Allow ALL" policies (uncomment to apply)

-- ALTER TABLE lead_stages ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Allow all" ON lead_stages FOR ALL USING (true) WITH CHECK (true);

-- ALTER TABLE leads ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Allow all" ON leads FOR ALL USING (true) WITH CHECK (true);

-- ALTER TABLE teachers ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Allow all" ON teachers FOR ALL USING (true) WITH CHECK (true);

-- ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Allow all" ON courses FOR ALL USING (true) WITH CHECK (true);

-- ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Allow all" ON rooms FOR ALL USING (true) WITH CHECK (true);

-- ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Allow all" ON groups FOR ALL USING (true) WITH CHECK (true);

-- ALTER TABLE students ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Allow all" ON students FOR ALL USING (true) WITH CHECK (true);

-- ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Allow all" ON attendance FOR ALL USING (true) WITH CHECK (true);

-- ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Allow all" ON payments FOR ALL USING (true) WITH CHECK (true);

-- ALTER TABLE payment_reminders ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Allow all" ON payment_reminders FOR ALL USING (true) WITH CHECK (true);

-- ALTER TABLE boards ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Allow all" ON boards FOR ALL USING (true) WITH CHECK (true);

-- ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Allow all" ON tasks FOR ALL USING (true) WITH CHECK (true);

-- ALTER TABLE archives ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Allow all" ON archives FOR ALL USING (true) WITH CHECK (true);

-- ALTER TABLE staff ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Allow all" ON staff FOR ALL USING (true) WITH CHECK (true);
