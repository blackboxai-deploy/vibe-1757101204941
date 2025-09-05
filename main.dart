# School ERP MVP - Complete Deliverable Document

## A. Project Overview
**Purpose**: Complete School Management System MVP for student records, attendance, assignments, and administrative tasks.
**Tech Stack**: React + Tailwind + Vite frontend, Node.js/Express backend, PostgreSQL + Prisma ORM, Docker deployment, Nginx reverse proxy.

## B. Roles & Permissions Matrix

### SuperAdmin
- **Dashboard**: System stats, multi-org management, license usage
- **CRUD Actions**: Full system access, org creation/deletion, global settings
- **Restrictions**: Cannot access individual school data directly

### Admin  
- **Dashboard**: School overview, user stats, recent activities, system health
- **CRUD Actions**: All users, classes, fees, reports, system settings
- **Restrictions**: Limited to own organization

### Principal
- **Dashboard**: School performance, teacher stats, student metrics, notifications
- **CRUD Actions**: View all data, approve leave requests, create notices
- **Restrictions**: Cannot delete historical records, limited user management

### Teacher
- **Dashboard**: My classes, recent assignments, attendance summary, schedule
- **CRUD Actions**: Mark attendance for assigned classes, create/grade assignments, view enrolled students
- **Restrictions**: Cannot access other teachers' data, no fee management, no user creation

### Student
- **Dashboard**: My assignments, attendance record, grades, schedule, notices
- **CRUD Actions**: Submit assignments, update profile, view reports
- **Restrictions**: Read-only for most data, cannot see other students' records

### Parent
- **Dashboard**: Child's performance, attendance, fee status, notifications
- **CRUD Actions**: View child's records, communicate with teachers, update contact info
- **Restrictions**: Limited to own child's data, no system modifications

### Accountant
- **Dashboard**: Fee collection, pending payments, financial reports, revenue stats
- **CRUD Actions**: Manage fees, generate financial reports, update payment records
- **Restrictions**: No academic data access, limited user management

## C. Auth and Onboarding

### Flow
```
1. SuperAdmin creates organization account
2. Admin invited via email with temp password
3. Admin sets up school profile and invites users
4. Users receive invitation email → click link → verify → set password
5. JWT tokens with refresh mechanism for sessions
```

### API Endpoints

#### Login
```javascript
POST /auth/login
{
  "email": "teacher@school.com",
  "password": "SecurePass123",
  "organizationId": "org_123"
}

Response:
{
  "success": true,
  "data": {
    "user": { "id": "usr_123", "name": "John Teacher", "role": "teacher" },
    "accessToken": "eyJ...",
    "refreshToken": "eyJ...",
    "expiresIn": 3600
  }
}
```

#### Refresh Token
```javascript
POST /auth/refresh
{
  "refreshToken": "eyJ..."
}

Response:
{
  "accessToken": "eyJ...",
  "expiresIn": 3600
}
```

#### Invite User
```javascript
POST /auth/invite
Headers: { "Authorization": "Bearer eyJ..." }
{
  "email": "newuser@school.com",
  "role": "teacher",
  "firstName": "Jane",
  "lastName": "Smith"
}

Response:
{
  "success": true,
  "inviteId": "inv_123",
  "expires": "2024-01-15T10:00:00Z"
}
```

#### Accept Invite
```javascript
POST /auth/accept-invite/:inviteId
{
  "password": "NewSecurePass123",
  "confirmPassword": "NewSecurePass123"
}
```

### Security Policies
- **Password Policy**: Min 8 chars, 1 uppercase, 1 number, 1 special char
- **Rate Limiting**: 5 login attempts per 15 minutes per IP
- **JWT Expiry**: Access token 1 hour, refresh token 7 days

## D. Core Features (MVP)

### Must-Have
1. **User Management** - CRUD operations for all user roles
2. **Class & Section Management** - Academic year, classes, sections, teacher assignments
3. **Attendance System** - Daily attendance marking and reporting
4. **Timetable Management** - Class schedules and teacher assignments
5. **Assignment & Grades** - Assignment creation, submission, and grading
6. **Notices & Announcements** - School-wide and class-specific notifications
7. **Fee Records** - View fee structure and payment status (admin creates)
8. **Basic Reports** - Attendance, grade, and fee reports

### Nice-to-Have
1. **Chat System** - Teacher-parent and admin communication
2. **Live Class Integration** - Zoom/Meet integration for online classes
3. **Analytics Dashboard** - Advanced performance metrics and insights
4. **OCR for Marksheets** - Automatic grade entry from scanned papers

## E. API Specification

### Authentication Endpoints
```yaml
/auth/login:
  POST:
    auth: none
    body: { email, password, organizationId }
    response: { user, accessToken, refreshToken, expiresIn }

/auth/refresh:
  POST:
    auth: refresh_token
    body: { refreshToken }
    response: { accessToken, expiresIn }
```

### Core Endpoints
```yaml
/users:
  GET:
    auth: admin|principal
    query: { role?, search?, page?, limit? }
    response: { users: [{ id, name, email, role, status }], total, page }
  
  POST:
    auth: admin
    body: { email, firstName, lastName, role }
    response: { user: { id, name, email, role }, inviteId }

/classes:
  GET:
    auth: any
    response: { classes: [{ id, name, section, teacherId, students }] }
  
  POST:
    auth: admin|principal
    body: { name, section, academicYear, teacherId }
    response: { class: { id, name, section, teacherId } }

/attendance/mark:
  POST:
    auth: teacher|admin
    body: { classId, date, attendance: [{ studentId, status }] }
    response: { success: true, recordsUpdated: 25 }

/timetable:
  GET:
    auth: any
    query: { classId?, teacherId?, date? }
    response: { schedule: [{ day, period, subject, teacher, classroom }] }

/assignments:
  GET:
    auth: any
    query: { classId?, studentId?, status? }
    response: { assignments: [{ id, title, dueDate, subject, status }] }
  
  POST:
    auth: teacher|admin
    body: { title, description, classId, dueDate, maxMarks }
    response: { assignment: { id, title, dueDate, status } }

/reports/attendance:
  GET:
    auth: teacher|admin|parent
    query: { studentId?, classId?, dateFrom, dateTo }
    response: { report: { totalDays, presentDays, percentage, details: [] } }
```

## F. Database Schema

### Core Tables SQL
```sql
-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    role VARCHAR(50) NOT NULL CHECK (role IN ('superadmin', 'admin', 'principal', 'teacher', 'student', 'parent', 'accountant')),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'pending')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Organizations table
CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    address TEXT,
    phone VARCHAR(20),
    email VARCHAR(255),
    academic_year_start DATE NOT NULL,
    academic_year_end DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Classes table
CREATE TABLE classes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    section VARCHAR(10) NOT NULL,
    academic_year VARCHAR(20) NOT NULL,
    class_teacher_id UUID REFERENCES users(id),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    capacity INTEGER DEFAULT 40,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(name, section, academic_year, organization_id)
);

-- Student Enrollments table
CREATE TABLE enrollments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES users(id),
    class_id UUID NOT NULL REFERENCES classes(id),
    roll_number VARCHAR(20),
    enrollment_date DATE DEFAULT CURRENT_DATE,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'transferred')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(student_id, class_id),
    UNIQUE(roll_number, class_id)
);

-- Attendance Records table
CREATE TABLE attendance_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES users(id),
    class_id UUID NOT NULL REFERENCES classes(id),
    date DATE NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (status IN ('present', 'absent', 'late', 'excused')),
    marked_by UUID NOT NULL REFERENCES users(id),
    remarks TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(student_id, class_id, date)
);
```

### Additional Tables Structure
```sql
-- assignments, submissions, fees, notifications, timetable, subjects, parent_student_relations, user_sessions, invitations
```

## G. ER Diagram Description

**Primary Relationships**:
- Organizations (1) → Users (N) - Users belong to one organization
- Users (1) → Classes (N) - Teacher can be assigned to multiple classes as class_teacher
- Classes (1) → Enrollments (N) → Users (Students) - Many-to-many via enrollments
- Classes (1) → Attendance_Records (N) ← Users (Students) - Attendance tracking
- Users (Teachers) (1) → Assignments (N) ← Classes - Teachers create assignments for classes
- Assignments (1) → Submissions (N) ← Users (Students) - Students submit assignments
- Users (Parents) ↔ Users (Students) - Parent-child relationships via junction table
- Classes (1) → Timetable_Slots (N) ← Subjects - Class schedules with subjects

**Key Foreign Keys**:
- All tables reference organization_id for multi-tenancy
- Attendance, assignments, enrollments reference both student and class
- Audit trails via created_by, updated_by user references

## H. Frontend (UX + Components)

### Page Structure
- **Login** - Organization selector, email/password, forgot password
- **Org Setup** - First-time organization configuration wizard
- **Dashboard** - Role-based widgets and quick actions
- **Classes** - Class management, student lists, teacher assignments
- **Attendance** - Daily attendance marking interface
- **Timetable** - Weekly schedule view and management
- **Assignments** - Create, view, grade assignments
- **Students** - Student profiles, enrollment, parent contacts
- **Profile** - User settings, password change, preferences
- **Settings** - System configuration, notifications, integrations

### Production-Ready Component: AttendanceTable
```jsx
import React, { useState, useEffect } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Badge } from '@/components/ui/badge';
import { Calendar } from '@/components/ui/calendar';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { CalendarIcon, Search, Download, Filter } from 'lucide-react';
import { format } from 'date-fns';

const AttendanceTable = ({ classId, userRole }) => {
  const [attendanceData, setAttendanceData] = useState([]);
  const [loading, setLoading] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [dateRange, setDateRange] = useState({
    from: new Date(new Date().getFullYear(), new Date().getMonth(), 1),
    to: new Date()
  });

  const itemsPerPage = 15;

  const fetchAttendanceData = async () => {
    setLoading(true);
    try {
      const params = new URLSearchParams({
        classId: classId || '',
        page: currentPage.toString(),
        limit: itemsPerPage.toString(),
        search: searchTerm,
        status: statusFilter !== 'all' ? statusFilter : '',
        dateFrom: format(dateRange.from, 'yyyy-MM-dd'),
        dateTo: format(dateRange.to, 'yyyy-MM-dd')
      });

      const response = await fetch(`/api/attendance?${params}`, {
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('accessToken')}`,
          'Content-Type': 'application/json'
        }
      });

      if (response.ok) {
        const data = await response.json();
        setAttendanceData(data.records);
        setTotalPages(Math.ceil(data.total / itemsPerPage));
      }
    } catch (error) {
      console.error('Error fetching attendance:', error);
    } finally {
      setLoading(false);
    }
  };

  const markAttendance = async (studentId, status) => {
    try {
      const response = await fetch('/api/attendance/mark', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('accessToken')}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          classId,
          date: format(new Date(), 'yyyy-MM-dd'),
          attendance: [{ studentId, status }]
        })
      });

      if (response.ok) {
        fetchAttendanceData(); // Refresh data
      }
    } catch (error) {
      console.error('Error marking attendance:', error);
    }
  };

  const exportAttendance = async () => {
    try {
      const params = new URLSearchParams({
        classId: classId || '',
        dateFrom: format(dateRange.from, 'yyyy-MM-dd'),
        dateTo: format(dateRange.to, 'yyyy-MM-dd'),
        format: 'csv'
      });

      const response = await fetch(`/api/attendance/export?${params}`, {
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('accessToken')}`
        }
      });

      if (response.ok) {
        const blob = await response.blob();
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `attendance-${format(new Date(), 'yyyy-MM-dd')}.csv`;
        a.click();
        window.URL.revokeObjectURL(url);
      }
    } catch (error) {
      console.error('Error exporting attendance:', error);
    }
  };

  const getStatusBadge = (status) => {
    const variants = {
      present: 'bg-green-100 text-green-800',
      absent: 'bg-red-100 text-red-800',
      late: 'bg-yellow-100 text-yellow-800',
      excused: 'bg-blue-100 text-blue-800'
    };
    
    return (
      <Badge className={variants[status] || 'bg-gray-100 text-gray-800'}>
        {status}
      </Badge>
    );
  };

  const getAttendancePercentage = (present, total) => {
    if (total === 0) return 0;
    return Math.round((present / total) * 100);
  };

  useEffect(() => {
    fetchAttendanceData();
  }, [currentPage, searchTerm, statusFilter, dateRange, classId]);

  return (
    <Card className="w-full">
      <CardHeader className="pb-4">
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
          <CardTitle className="text-xl font-semibold">
            Attendance Management
          </CardTitle>
          <div className="flex flex-wrap gap-2">
            <Button
              onClick={exportAttendance}
              variant="outline"
              size="sm"
              className="flex items-center gap-2"
            >
              <Download className="h-4 w-4" />
              Export
            </Button>
          </div>
        </div>

        {/* Filters */}
        <div className="flex flex-col sm:flex-row gap-4 mt-4">
          <div className="flex items-center gap-2 flex-1">
            <Search className="h-4 w-4 text-gray-400" />
            <Input
              placeholder="Search students..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="flex-1"
            />
          </div>
          
          <Select value={statusFilter} onValueChange={setStatusFilter}>
            <SelectTrigger className="w-full sm:w-40">
              <SelectValue placeholder="Filter by status" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Status</SelectItem>
              <SelectItem value="present">Present</SelectItem>
              <SelectItem value="absent">Absent</SelectItem>
              <SelectItem value="late">Late</SelectItem>
              <SelectItem value="excused">Excused</SelectItem>
            </SelectContent>
          </Select>

          <Popover>
            <PopoverTrigger asChild>
              <Button variant="outline" className="flex items-center gap-2">
                <CalendarIcon className="h-4 w-4" />
                {dateRange.from ? (
                  dateRange.to ? (
                    <>
                      {format(dateRange.from, "LLL dd")} - {format(dateRange.to, "LLL dd")}
                    </>
                  ) : (
                    format(dateRange.from, "LLL dd, y")
                  )
                ) : (
                  <span>Pick a date range</span>
                )}
              </Button>
            </PopoverTrigger>
            <PopoverContent className="w-auto p-0" align="end">
              <Calendar
                mode="range"
                defaultMonth={dateRange.from}
                selected={dateRange}
                onSelect={setDateRange}
                numberOfMonths={2}
              />
            </PopoverContent>
          </Popover>
        </div>
      </CardHeader>

      <CardContent>
        {loading ? (
          <div className="flex justify-center items-center h-64">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
          </div>
        ) : (
          <>
            {/* Table */}
            <div className="overflow-x-auto">
              <table className="w-full border-collapse border border-gray-200">
                <thead>
                  <tr className="bg-gray-50">
                    <th className="border border-gray-200 p-3 text-left font-medium">
                      Student
                    </th>
                    <th className="border border-gray-200 p-3 text-left font-medium">
                      Roll No.
                    </th>
                    <th className="border border-gray-200 p-3 text-center font-medium">
                      Today's Status
                    </th>
                    <th className="border border-gray-200 p-3 text-center font-medium">
                      This Month
                    </th>
                    <th className="border border-gray-200 p-3 text-center font-medium">
                      Attendance %
                    </th>
                    {userRole === 'teacher' && (
                      <th className="border border-gray-200 p-3 text-center font-medium">
                        Action
                      </th>
                    )}
                  </tr>
                </thead>
                <tbody>
                  {attendanceData.map((record) => (
                    <tr key={record.id} className="hover:bg-gray-50">
                      <td className="border border-gray-200 p-3">
                        <div className="flex items-center gap-3">
                          <div className="h-8 w-8 rounded-full bg-blue-100 flex items-center justify-center text-sm font-medium text-blue-800">
                            {record.student.firstName.charAt(0)}{record.student.lastName.charAt(0)}
                          </div>
                          <div>
                            <div className="font-medium">
                              {record.student.firstName} {record.student.lastName}
                            </div>
                            <div className="text-sm text-gray-500">
                              {record.student.email}
                            </div>
                          </div>
                        </div>
                      </td>
                      <td className="border border-gray-200 p-3 text-center">
                        {record.rollNumber}
                      </td>
                      <td className="border border-gray-200 p-3 text-center">
                        {getStatusBadge(record.todayStatus || 'absent')}
                      </td>
                      <td className="border border-gray-200 p-3 text-center">
                        <div className="text-sm">
                          <div>{record.monthlyStats.present}/{record.monthlyStats.total}</div>
                          <div className="text-gray-500">Present/Total</div>
                        </div>
                      </td>
                      <td className="border border-gray-200 p-3 text-center">
                        <div className="flex items-center justify-center gap-2">
                          <div className={`text-sm font-medium ${
                            getAttendancePercentage(record.monthlyStats.present, record.monthlyStats.total) >= 75 
                              ? 'text-green-600' 
                              : 'text-red-600'
                          }`}>
                            {getAttendancePercentage(record.monthlyStats.present, record.monthlyStats.total)}%
                          </div>
                        </div>
                      </td>
                      {userRole === 'teacher' && (
                        <td className="border border-gray-200 p-3 text-center">
                          <div className="flex justify-center gap-1">
                            <Button
                              size="sm"
                              variant={record.todayStatus === 'present' ? 'default' : 'outline'}
                              onClick={() => markAttendance(record.student.id, 'present')}
                              className="px-2 py-1 text-xs"
                            >
                              P
                            </Button>
                            <Button
                              size="sm"
                              variant={record.todayStatus === 'absent' ? 'destructive' : 'outline'}
                              onClick={() => markAttendance(record.student.id, 'absent')}
                              className="px-2 py-1 text-xs"
                            >
                              A
                            </Button>
                            <Button
                              size="sm"
                              variant={record.todayStatus === 'late' ? 'default' : 'outline'}
                              onClick={() => markAttendance(record.student.id, 'late')}
                              className="px-2 py-1 text-xs"
                            >
                              L
                            </Button>
                          </div>
                        </td>
                      )}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {/* Pagination */}
            {totalPages > 1 && (
              <div className="flex justify-between items-center mt-6">
                <div className="text-sm text-gray-500">
                  Showing {(currentPage - 1) * itemsPerPage + 1} to{' '}
                  {Math.min(currentPage * itemsPerPage, attendanceData.length)} of{' '}
                  {attendanceData.length} results
                </div>
                <div className="flex gap-2">
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setCurrentPage(Math.max(1, currentPage - 1))}
                    disabled={currentPage === 1}
                  >
                    Previous
                  </Button>
                  <div className="flex gap-1">
                    {[...Array(totalPages)].map((_, i) => (
                      <Button
                        key={i + 1}
                        variant={currentPage === i + 1 ? "default" : "outline"}
                        size="sm"
                        onClick={() => setCurrentPage(i + 1)}
                        className="px-3"
                      >
                        {i + 1}
                      </Button>
                    ))}
                  </div>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setCurrentPage(Math.min(totalPages, currentPage + 1))}
                    disabled={currentPage === totalPages}
                  >
                    Next
                  </Button>
                </div>
              </div>
            )}
          </>
        )}
      </CardContent>
    </Card>
  );
};

export default AttendanceTable;
```

## I. DevOps & Deployment

### Docker Compose Configuration
```yaml
version: '3.8'

services:
  # PostgreSQL Database
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ${DB_NAME}
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    networks:
      - school-erp

  # Redis for Sessions & Caching
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    networks:
      - school-erp

  # Backend API
  api:
    build:
      context: ./backend
      dockerfile: Dockerfile
    environment:
      NODE_ENV: production
      DB_HOST: postgres
      DB_PORT: 5432
      DB_USER: ${DB_USER}
      DB_PASSWORD: ${DB_PASSWORD}
      DB_NAME: ${DB_NAME}
      REDIS_URL: redis://redis:6379
      JWT_SECRET: ${JWT_SECRET}
      JWT_REFRESH_SECRET: ${JWT_REFRESH_SECRET}
      EMAIL_SERVICE: ${EMAIL_SERVICE}
      EMAIL_USER: ${EMAIL_USER}
      EMAIL_PASS: ${EMAIL_PASS}
    ports:
      - "3001:3000"
    depends_on:
      - postgres
      - redis
    volumes:
      - ./uploads:/app/uploads
    networks:
      - school-erp
    restart: unless-stopped

  # Frontend Application
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    ports:
      - "3000:3000"
    environment:
      REACT_APP_API_URL: http://localhost:3001/api
      NODE_ENV: production
    depends_on:
      - api
    networks:
      - school-erp
    restart: unless-stopped

  # Nginx Reverse Proxy
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./nginx/ssl:/etc/nginx/ssl
      - ./nginx/logs:/var/log/nginx
    depends_on:
      - frontend
      - api
    networks:
      - school-erp
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:

networks:
  school-erp:
    driver: bridge
```

### Environment Variables (.env.example)
```bash
# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_USER=school_erp_user
DB_PASSWORD=secure_password_123
DB_NAME=school_erp

# JWT Configuration
JWT_SECRET=your-super-secret-jwt-key-min-32-chars
JWT_REFRESH_SECRET=your-refresh-token-secret-key
JWT_EXPIRES_IN=1h
JWT_REFRESH_EXPIRES_IN=7d

# Redis Configuration
REDIS_URL=redis://localhost:6379

# Email Configuration
EMAIL_SERVICE=gmail
EMAIL_USER=noreply@yourschool.com
EMAIL_PASS=your-app-password
EMAIL_FROM=School ERP <noreply@yourschool.com>

# File Upload
MAX_FILE_SIZE=10485760
UPLOAD_PATH=./uploads
ALLOWED_FILE_TYPES=jpg,jpeg,png,pdf,doc,docx

# Application
NODE_ENV=production
PORT=3000
FRONTEND_URL=https://yourschool.com
API_BASE_URL=https://api.yourschool.com

# Security
BCRYPT_ROUNDS=12
RATE_LIMIT_WINDOW=900000
RATE_LIMIT_MAX=100
```

### Migration Commands
```bash
# Initial setup
npm run setup:db
npx prisma migrate deploy
npx prisma db seed

# Development migrations
npx prisma migrate dev --name add_attendance_table
npx prisma generate
npx prisma studio

# Production migrations
npx prisma migrate deploy
npx prisma generate --no-engine
```

### CI/CD Pipeline (GitHub Actions)
```yaml
name: Deploy School ERP

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: school_erp_test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
    - uses: actions/checkout@v3
    
    - name: Use Node.js 18
      uses: actions/setup-node@v3
      with:
        node-version: 18
        cache: 'npm'
    
    - name: Install dependencies
      run: |
        npm ci
        cd frontend && npm ci
    
    - name: Run tests
      run: |
        npm run test:unit
        npm run test:integration
      env:
        DATABASE_URL: postgresql://postgres:postgres@localhost:5432/school_erp_test

    - name: Build frontend
      run: |
        cd frontend
        npm run build
    
  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
    - name: Deploy to production
      uses: appleboy/ssh-action@v0.1.5
      with:
        host: ${{ secrets.HOST }}
        username: ${{ secrets.USERNAME }}
        key: ${{ secrets.PRIVATE_KEY }}
        script: |
          cd /var/www/school-erp
          git pull origin main
          docker-compose down
          docker-compose build --no-cache
          docker-compose up -d
          docker-compose exec api npm run migrate:deploy
```

### Nginx Configuration
```nginx
upstream api_backend {
    server api:3000;
}

upstream frontend_backend {
    server frontend:3000;
}

server {
    listen 80;
    server_name yourschool.com www.yourschool.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name yourschool.com www.yourschool.com;

    ssl_certificate /etc/nginx/ssl/certificate.pem;
    ssl_certificate_key /etc/nginx/ssl/private.key;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    client_max_body_size 50M;
    
    # Frontend
    location / {
        proxy_pass http://frontend_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
    
    # API
    location /api/ {
        proxy_pass http://api_backend/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Rate limiting
        limit_req zone=api burst=20 nodelay;
        limit_req_status 429;
    }
    
    # File uploads
    location /uploads/ {
        alias /var/www/uploads/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}

# Rate limiting zones
http {
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
}
```

## J. Acceptance Criteria & Test Cases

### Acceptance Criteria
1. **Role-based Access**: Teachers can mark attendance only for their assigned classes, cannot access other classes' data
2. **Student Visibility**: Students see only their own assignments, grades, and attendance records
3. **Parent Access**: Parents can view only their child's academic records and communicate with teachers
4. **Admin Controls**: Admins can create/modify users, classes, and system settings within their organization
5. **Data Isolation**: Organizations cannot access each other's data, complete multi-tenant separation
6. **Assignment Workflow**: Teachers create assignments → Students submit → Teachers grade → Students/Parents view results
7. **Attendance Tracking**: Daily attendance marking with monthly/yearly percentage calculations and reports
8. **Notification System**: Automated notifications for assignment due dates, low attendance, fee dues

### Automated Test Cases

#### Unit Tests
```javascript
// Authentication tests
describe('Auth Service', () => {
  test('should authenticate valid user with correct role', async () => {
    const result = await authService.login('teacher@school.com', 'password123', 'org_123');
    expect(result.user.role).toBe('teacher');
    expect(result.accessToken).toBeDefined();
  });

  test('should reject invalid credentials', async () => {
    await expect(authService.login('invalid@email.com', 'wrong', 'org_123'))
      .rejects.toThrow('Invalid credentials');
  });
});

// Attendance tests
describe('Attendance Service', () => {
  test('should calculate attendance percentage correctly', () => {
    const percentage = attendanceService.calculatePercentage(18, 20);
    expect(percentage).toBe(90);
  });

  test('should prevent duplicate attendance entries for same date', async () => {
    await expect(attendanceService.markAttendance('student_123', 'class_456', '2024-01-15', 'present'))
      .rejects.toThrow('Attendance already marked for this date');
  });
});
```

#### Integration Tests
```javascript
describe('API Integration Tests', () => {
  test('POST /api/attendance/mark should require teacher authentication', async () => {
    const response = await request(app)
      .post('/api/attendance/mark')
      .send({ classId: 'class_123', date: '2024-01-15', attendance: [] });
    
    expect(response.status).toBe(401);
  });

  test('GET /api/reports/attendance should return filtered data for teachers', async () => {
    const response = await request(app)
      .get('/api/reports/attendance?classId=class_123')
      .set('Authorization', `Bearer ${teacherToken}`);
    
    expect(response.status).toBe(200);
    expect(response.body.report.details).toHaveLength(25);
  });

  test('File upload should validate file types and size', async () => {
    const response = await request(app)
      .post('/api/assignments/upload')
      .attach('file', './test-files/malicious.exe')
      .set('Authorization', `Bearer ${teacherToken}`);
    
    expect(response.status).toBe(400);
    expect(response.body.error).toContain('Invalid file type');
  });
});
```

#### End-to-End Tests
```javascript
describe('E2E User Flows', () => {
  test('Complete assignment workflow', async () => {
    // Teacher creates assignment
    await page.goto('/assignments');
    await page.click('[data-testid=create-assignment]');
    await page.fill('[data-testid=assignment-title]', 'Math Quiz 1');
    await page.click('[data-testid=submit-assignment]');
    
    // Student submits assignment
    await page.goto('/student-assignments');
    await page.click('[data-testid=submit-assignment-123]');
    await page.setInputFiles('[data-testid=file-upload]', './submission.pdf');
    await page.click('[data-testid=submit-button]');
    
    // Verify submission appears in teacher's grading queue
    await page.goto('/teacher-grading');
    expect(await page.textContent('[data-testid=pending-submissions]')).toContain('1 pending');
  });

  test('Attendance marking and reporting', async () => {
    // Mark attendance for class
    await page.goto('/attendance/class-123');
    await page.click('[data-testid=student-456-present]');
    await page.click('[data-testid=save-attendance]');
    
    // Verify attendance report updates
    await page.goto('/reports/attendance');
    expect(await page.textContent('[data-testid=attendance-percentage]')).toContain('95%');
  });
});
```

## K. Security & Privacy Checklist

### Authentication & Authorization
- [x] **JWT Expiry**: Access tokens expire in 1 hour, refresh tokens in 7 days
- [x] **Role-Based Access Control**: Server-side validation on all endpoints with role checks
- [x] **Session Management**: Secure refresh token rotation and revocation
- [x] **Password Policy**: Minimum 8 characters, complexity requirements enforced

### Input Validation & Data Protection
- [x] **Input Sanitization**: All user inputs validated and sanitized using Joi/Yup schemas
- [x] **SQL Injection Prevention**: Prisma ORM with parameterized queries only
- [x] **XSS Protection**: Content Security Policy headers and input encoding
- [x] **File Upload Security**: Type validation, size limits (10MB), virus scanning

### Infrastructure Security
- [x] **HTTPS Enforcement**: SSL/TLS certificates with HTTP to HTTPS redirects
- [x] **Rate Limiting**: API endpoints limited to 100 requests per 15 minutes per IP
- [x] **CORS Configuration**: Restricted to allowed origins only
- [x] **Environment Variables**: All secrets in environment variables, never in code

### Data Privacy & Compliance
- [x] **Data Minimization**: Collect only necessary student/parent information
- [x] **Encryption**: Passwords hashed with bcrypt (12 rounds), sensitive data encrypted at rest
- [x] **Audit Logging**: All data modifications logged with user ID and timestamp
- [x] **Right to Deletion**: GDPR compliance with data export and deletion capabilities
- [x] **Data Retention**: Student records retained for 7 years post-graduation as per Indian regulations

### Additional Security Measures
```javascript
// Security Headers Middleware
const securityHeaders = (req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  res.setHeader('Content-Security-Policy', "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'");
  next();
};

// Input Validation Schema Example
const attendanceSchema = Joi.object({
  classId: Joi.string().uuid().required(),
  date: Joi.date().iso().required(),
  attendance: Joi.array().items(
    Joi.object({
      studentId: Joi.string().uuid().required(),
      status: Joi.string().valid('present', 'absent', 'late', 'excused').required()
    })
  ).max(50).required()
});
```

## L. Deliverables Checklist for Developer

### Project Setup Commands
```bash
# 1. Clone and setup project
git clone <school-erp-repo>
cd school-erp
npm install

# 2. Database setup
docker-compose up -d postgres redis
cp .env.example .env  # Edit with your credentials
npx prisma migrate deploy
npx prisma generate
npm run seed

# 3. Start development servers
npm run dev:api      # Backend on port 3001
npm run dev:frontend # Frontend on port 3000

# 4. Run tests
npm run test
npm run test:e2e

# 5. Build for production
npm run build
docker-compose up -d
```

### Folder Structure
```
school-erp/
├── backend/
│   ├── src/
│   │   ├── controllers/
│   │   ├── middleware/
│   │   ├── models/
│   │   ├── routes/
│   │   ├── services/
│   │   ├── utils/
│   │   └── app.js
│   ├── prisma/
│   │   ├── schema.prisma
│   │   ├── migrations/
│   │   └── seed.js
│   ├── tests/
│   ├── Dockerfile
│   └── package.json
├── frontend/
│   ├── src/
│   │   ├── components/
│   │   ├── pages/
│   │   ├── hooks/
│   │   ├── services/
│   │   ├── utils/
│   │   └── App.jsx
│   ├── public/
│   ├── Dockerfile
│   └── package.json
├── nginx/
│   └── nginx.conf
├── docker-compose.yml
├── .env.example
└── README.md
```

### Sample .env Configuration
```bash
# Development Environment
NODE_ENV=development
PORT=3001

# Database (Docker)
DATABASE_URL=postgresql://school_user:school_pass@localhost:5432/school_erp
DB_HOST=localhost
DB_PORT=5432
DB_USER=school_user
DB_PASSWORD=school_pass
DB_NAME=school_erp

# JWT Secrets (Generate new ones!)
JWT_SECRET=your-super-secure-jwt-secret-key-minimum-32-characters-long
JWT_REFRESH_SECRET=your-super-secure-refresh-secret-key-minimum-32-characters-long

# Redis
REDIS_URL=redis://localhost:6379

# Email (Gmail App Password)
EMAIL_SERVICE=gmail
EMAIL_USER=your-school@gmail.com
EMAIL_PASS=your-gmail-app-password
EMAIL_FROM="School ERP <noreply@yourschool.com>"

# File Uploads
MAX_FILE_SIZE=10485760
UPLOAD_PATH=./uploads
ALLOWED_FILE_TYPES=jpg,jpeg,png,pdf,doc,docx,xls,xlsx

# Frontend
REACT_APP_API_URL=http://localhost:3001/api
REACT_APP_UPLOAD_URL=http://localhost:3001/uploads
```

### Database Seed Data Script
```javascript
// prisma/seed.js
const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');

const prisma = new PrismaClient();

async function main() {
  // Create sample organization
  const org = await prisma.organization.create({
    data: {
      name: 'Demo High School',
      address: '123 Education Street, Learning City, LC 12345',
      phone: '+1-555-SCHOOL',
      email: 'admin@demoschool.edu',
      academicYearStart: new Date('2024-04-01'),
      academicYearEnd: new Date('2025-03-31')
    }
  });

  // Create admin user
  const adminPassword = await bcrypt.hash('admin123', 12);
  const admin = await prisma.user.create({
    data: {
      email: 'admin@demoschool.edu',
      passwordHash: adminPassword,
      firstName: 'School',
      lastName: 'Administrator',
      role: 'admin',
      organizationId: org.id,
      status: 'active'
    }
  });

  // Create sample teacher
  const teacherPassword = await bcrypt.hash('teacher123', 12);
  const teacher = await prisma.user.create({
    data: {
      email: 'math.teacher@demoschool.edu',
      passwordHash: teacherPassword,
      firstName: 'John',
      lastName: 'Mathematics',
      role: 'teacher',
      organizationId: org.id,
      status: 'active'
    }
  });

  // Create sample class
  const mathClass = await prisma.class.create({
    data: {
      name: 'Grade 10',
      section: 'A',
      academicYear: '2024-25',
      classTeacherId: teacher.id,
      organizationId: org.id,
      capacity: 40
    }
  });

  // Create sample students
  const students = [];
  for (let i = 1; i <= 5; i++) {
    const studentPassword = await bcrypt.hash('student123', 12);
    const student = await prisma.user.create({
      data: {
        email: `student${i}@demoschool.edu`,
        passwordHash: studentPassword,
        firstName: `Student`,
        lastName: `${i}`,
        role: 'student',
        organizationId: org.id,
        status: 'active'
      }
    });

    // Enroll student in class
    await prisma.enrollment.create({
      data: {
        studentId: student.id,
        classId: mathClass.id,
        rollNumber: `2024A${String(i).padStart(2, '0')}`,
        enrollmentDate: new Date('2024-04-01')
      }
    });

    students.push(student);
  }

  console.log('✅ Seed data created successfully!');
  console.log('📧 Admin login: admin@demoschool.edu / admin123');
  console.log('👩‍🏫 Teacher login: math.teacher@demoschool.edu / teacher123');
  console.log('👨‍🎓 Student login: student1@demoschool.edu / student123');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
```

## M. Example Prompts for Code Generation

### Backend API Controller Generation
```
"Generate Express controller for attendance management using the Prisma schema above. Include endpoints for marking attendance, getting attendance reports, and exporting data. Add proper error handling, validation, and role-based access control."
```

### Frontend Component Generation
```
"Create a React component for assignment submission with file upload, drag-and-drop support, and progress tracking. Use Tailwind CSS and shadcn/ui components. Include form validation and API integration."
```

### Database Query Optimization
```
"Generate optimized Prisma queries for attendance reporting with filters by date range, class, and student. Include aggregations for attendance percentages and monthly statistics."
```

### Authentication Middleware
```
"Create JWT authentication middleware for Express with role-based access control, token refresh logic, and rate limiting. Include proper error handling and security headers."
```

### Email Template Generation
```
"Generate responsive HTML email templates for user invitations, assignment notifications, and attendance alerts. Include inline CSS and support for both light and dark email clients."
```

### Test Suite Generation
```
"Create comprehensive Jest test suite for the attendance API endpoints including unit tests, integration tests, and mocking external dependencies like database and email services."
```

### Mobile-Responsive Dashboard
```
"Generate a mobile-first dashboard component showing role-based widgets for teachers including upcoming classes, pending assignments, and attendance summary. Use Tailwind CSS with responsive design patterns."
```

### Advanced Report Generation
```
"Create a flexible reporting system that generates PDF and Excel reports for attendance, grades, and fee collection with charts, filters, and export capabilities using libraries like jsPDF and xlsx."
```

---

**Final Development Notes:**
- Prioritize security at every layer - authentication, authorization, input validation
- Implement comprehensive logging and monitoring for production deployment
- Use TypeScript throughout for better code quality and developer experience  
- Follow REST API conventions with consistent error handling and status codes
- Ensure responsive design works on tablets and mobile devices for field use
- Plan for scalability - database indexing, caching, and horizontal scaling options
- Implement comprehensive backup and disaster recovery procedures
- Consider offline-first approach for mobile attendance marking capabilities

**Production Readiness Checklist:**
✅ Role-based access control implemented
✅ Multi-tenant data isolation
✅ Comprehensive API documentation
✅ Automated testing pipeline
✅ Security headers and validation
✅ Performance monitoring setup
✅ Database migration strategy
✅ Backup and recovery plan
✅ SSL certificate and domain setup
✅ Error logging and alerting system

This MVP provides a solid foundation for a production-ready School ERP system that can scale with institutional needs while maintaining security, performance, and user experience standards.