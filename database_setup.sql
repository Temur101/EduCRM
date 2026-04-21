-- EduCRM Complete Database Schema (Updated & Synchronized)
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
    email TEXT UNIQUE,
    password TEXT DEFAULT 'teacher123',
    percentage INTEGER DEFAULT 0,
    status TEXT DEFAULT 'Active',
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT now(),
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
    teacher_ids UUID[] DEFAULT '{}',
    room TEXT,
    days TEXT[],
    time TEXT,
    status TEXT DEFAULT 'Active',
    students_list UUID[] DEFAULT '{}',
    is_deleted BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 8. Create students table
CREATE TABLE IF NOT EXISTS students (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    phone TEXT,
    phone2 TEXT,
    email TEXT,
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

-- 14. Create staff table
CREATE TABLE IF NOT EXISTS staff (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    email TEXT UNIQUE,
    phone TEXT,
    password TEXT NOT NULL DEFAULT 'staff123',
    role TEXT DEFAULT 'regular',
    status TEXT DEFAULT 'Active',
    updated_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 15. Create archives table
CREATE TABLE IF NOT EXISTS archives (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type TEXT NOT NULL,
    original_id UUID,
    data JSONB NOT NULL,
    archived_at TIMESTAMPTZ DEFAULT now()
);

-- 16. Initial Data
INSERT INTO boards (title, color) VALUES ('Today task list', '#EA5455') ON CONFLICT DO NOTHING;

-- 17. Security Policy Setup
DO $$
DECLARE
    t TEXT;
BEGIN
    FOR t IN SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' 
    LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY;', t);
        EXECUTE format('DROP POLICY IF EXISTS "Allow all" ON %I;', t);
        EXECUTE format('CREATE POLICY "Allow all" ON %I FOR ALL USING (true) WITH CHECK (true);', t);
    END LOOP;
END $$;
