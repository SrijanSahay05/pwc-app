# PWC Entrance Exam Application

A Django REST API application for managing entrance exam applications for PWC Institute. The application handles user registration, authentication, course applications, and educational details management.

## Project Structure

```
pwc-app/
├── core/                          # Main Django project
│   ├── settings.py
│   ├── urls.py                    # Main URL configuration
│   └── wsgi.py
├── core_users/                    # User management app
│   ├── authentication_models.py   # CustomUser and RegistrationSession models
│   ├── models.py                  # UserApplication and EducationDetails models
│   ├── api_views.py              # API views for user management
│   ├── serializers.py            # Serializers for user data
│   ├── services.py               # Business logic services
│   └── api_urls.py               # URL patterns for user APIs
├── feature_entrance_exam/         # Course application app
│   ├── models.py                  # Academic models (Degree, Program, Major, etc.)
│   ├── views.py                   # Course application API views
│   ├── serializers.py            # Serializers for course data
│   └── urls.py                    # URL patterns for course APIs
└── manage.py
```

## User Registration Flow

1. **Start Registration**: User enters Email, Phone, First Name, Last Name (saved as RegistrationSession Model)
2. **OTP Verification**: Verifies Email and Phone using OTP services
3. **Set Password**: User sets their account password
4. **Account Creation**: CustomUser Model is created and RegistrationSession Model is deleted
5. **Profile Setup**: UserApplication and EducationDetails models are automatically created

## API Endpoints

### Core Users App (`/api/`)

#### Authentication Endpoints

- **POST** `/api/register/`
  - Start user registration process
  - **Body**: `{email, phone, first_name, last_name}`
  - **Response**: `{session_id, detail}`

- **POST** `/api/verify-otp/`
  - Verify email and phone OTPs
  - **Body**: `{session_id, email_otp, phone_otp}`
  - **Response**: `{detail}` or `{email_otp, phone_otp}` (error messages)

- **POST** `/api/resend-otp/`
  - Resend OTPs to email and phone
  - **Body**: `{email, phone}`
  - **Response**: `{detail}`

- **POST** `/api/set-password/`
  - Complete registration by setting password
  - **Body**: `{session_id, password, confirm_password}`
  - **Response**: `{detail, user}`

- **POST** `/api/login/`
  - User login
  - **Body**: `{email, password}`
  - **Response**: `{refresh, access, user}`

#### User Profile Endpoints

- **GET** `/api/me/`
  - Get current user profile
  - **Headers**: `Authorization: Bearer <token>`
  - **Response**: `{id, email, phone, first_name, last_name, is_admitted, admission_date}`

- **GET** `/api/user-application/`
  - Get user's application details
  - **Headers**: `Authorization: Bearer <token>`
  - **Response**: User application data

- **PUT** `/api/user-application/`
  - Update user's application details
  - **Headers**: `Authorization: Bearer <token>`
  - **Body**: User application fields
  - **Response**: `{detail, user_application}`

- **GET** `/api/user-education-details/`
  - Get user's education details
  - **Headers**: `Authorization: Bearer <token>`
  - **Response**: Education details data

- **PUT** `/api/user-education-details/`
  - Update user's education details
  - **Headers**: `Authorization: Bearer <token>`
  - **Body**: Education details fields
  - **Response**: `{detail, user_education_detail}`

### Feature Entrance Exam App (`/api/`)

#### Course Application Endpoints

- **PUT** `/api/course-application/`
  - Update course application selections
  - **Headers**: `Authorization: Bearer <token>`
  - **Body**: `{degree, program, major, minor, mdc, vac, aec, aoc}`
  - **Response**: 
    ```json
    {
      "selected_values": {
        "id": 1,
        "degree": {...},
        "program": {...},
        "major": {...},
        "minor": {...},
        "mdc": {...},
        "vac": {...},
        "aec": {...},
        "aoc": {...},
        "fee_amount": "1000.00",
        "is_fee_paid": false
      },
      "available_options": {
        "degrees": [...],
        "programs": [...],
        "majors": [...],
        "minors": [...],
        "mdcs": [...],
        "vacs": [...],
        "aecs": [...],
        "aocs": [...]
      }
    }
    ```

## Data Models

### Core Users App

#### CustomUser
- `email` (unique)
- `phone` (unique)
- `first_name`, `last_name`
- `is_admitted`, `admission_date`
- `created_at`, `updated_at`

#### RegistrationSession
- `email`, `phone`
- `first_name`, `last_name`
- `is_email_verified`, `is_phone_verified`
- `expires_at`

#### UserApplication
- `user` (OneToOneField to CustomUser)
- `application_id` (auto-generated: PWC{year}{sequence})
- Personal details: `date_of_birth`, `gender`, `profile_picture`
- Address: `current_address`, `permanent_address`
- Family details: `father_name`, `mother_name`, etc.
- Certificates: `aadhaar_number`, `caste_certificate`, `ews_certificate`, `disability_certificate`

#### EducationDetailsModel
- `user` (OneToOneField to CustomUser)
- `user_application` (OneToOneField to UserApplication)
- 10th details: `school_name_10th`, `school_board_10th`, subject marks
- 12th details: `school_name_12th`, `school_board_12th`, `subject_stream`, subject marks
- `is_appearing` (boolean for 12th appearing students)

### Feature Entrance Exam App

#### Academic Structure
- **Degree**: Top-level academic degree (e.g., Bachelor's, Master's)
- **Program**: Specific program under a degree (e.g., B.Sc, BBA, MCA)
- **Major**: Specialization under a program (e.g., Computer Science, Physics)
- **Minor**: Additional specialization courses
- **MultiDisciplinaryCourse (MDC)**: Cross-disciplinary courses
- **ValueAddedCourse (VAC)**: Skill enhancement courses
- **AbilityEnhancementCourse (AEC)**: General ability courses
- **AddOnCourse (AOC)**: Additional paid courses

#### CourseApplication
- Links user to their course selections
- Tracks fee payment status
- Maintains application state

## Features

### User Management
- ✅ Email and phone verification via OTP
- ✅ Secure password-based authentication
- ✅ JWT token-based session management
- ✅ User profile management
- ✅ Application ID generation

### Course Application
- ✅ Hierarchical course selection (Degree → Program → Major)
- ✅ Dynamic available options based on selections
- ✅ Fee calculation and payment tracking
- ✅ Support for multiple course types (Minor, MDC, VAC, AEC, AOC)

### Education Details
- ✅ 10th and 12th education details
- ✅ Support for appearing students
- ✅ Automatic total marks calculation
- ✅ Stream-based course recommendations

## TODO Items

### 🔐 Authentication & Security
- [x] **OTP System**: Email and phone OTP generation and verification system implemented
- [ ] **Fix OTP Verification**: Resolve OTP code mismatch for standalone email and phone verification
- [ ] **Password Reset Flow**: Implement complete forgot password functionality with email/SMS verification
- [ ] **Session Management**: Add session timeout and automatic logout features
- [ ] **Rate Limiting**: Implement API rate limiting to prevent abuse
- [ ] **Input Validation**: Add comprehensive server-side validation for all user inputs
- [ ] **Security Headers**: Add security headers and CSRF protection

### 📊 Data Management & Validation
- [x] **Application ID Generation**: Auto-generated application IDs (PWC{year}{sequence}) implemented
- [x] **User Registration Flow**: Complete registration session management with expiry
- [ ] **Model Validation**: Add custom model-level validation and save methods where needed
- [ ] **ID Management**: Centralize all ID numbers in CustomUser model (application_id, form_id, class_roll, exam_roll, registration_number)
- [ ] **Data Integrity**: Implement database constraints and validation rules
- [ ] **Audit Trail**: Add logging for all critical user actions and data changes
- [ ] **Data Export**: Create admin tools for data export and reporting

### 💳 Payment & Financial
- [ ] **Payment Gateway Integration**: Integrate with payment gateways (Razorpay/Stripe)
- [ ] **Payment Validation**: Add stream and eligibility validation before payment processing
- [ ] **Receipt Generation**: Automatically generate and email payment receipts
- [ ] **Refund Management**: Implement refund processing and tracking
- [ ] **Fee Calculation**: Dynamic fee calculation based on course combinations
- [ ] **Payment History**: Track and display payment history for users

### 🎓 Course Application System
- [x] **Hierarchical Course Selection**: Degree → Program → Major selection system implemented
- [x] **Dynamic Available Options**: Real-time course options based on user selections
- [x] **Course Application Model**: Complete course application tracking with fee status
- [x] **Universal Course Support**: Support for Minor, MDC, VAC, AEC, AOC courses
- [ ] **Stream Validation**: Check applicant's 12th stream against program's `pre_req_stream` requirements
- [ ] **Multiple Program Applications**: Allow users to apply for multiple programs with separate applications
- [ ] **Dynamic Preference Lists**: Implement preference-based course selection within same program
- [ ] **Single Payment for Multiple Preferences**: Enable one-time payment for multiple course combinations
- [ ] **Application Priority Management**: Add priority ordering system for course preferences
- [ ] **Seat Allocation Logic**: Implement intelligent seat allocation based on preferences and availability
- [ ] **Application Status Tracking**: Real-time status updates for application processing
- [ ] **Course Availability Check**: Real-time seat availability checking

### 📧 Communication & Notifications
- [ ] **Email Notifications**: Automated email notifications for application status updates
- [ ] **SMS Notifications**: SMS alerts for important updates and reminders
- [ ] **Admin Notifications**: Notify admins about new applications and issues
- [ ] **Reminder System**: Automated reminders for incomplete applications
- [ ] **Status Updates**: Real-time status updates via email/SMS

### 🛠️ Admin & Management
- [x] **Django Admin Integration**: Basic admin interface for all models implemented
- [x] **Model Admin Classes**: Customized admin views for courses, applications, and users
- [ ] **Admin Dashboard**: Comprehensive admin dashboard for course and application management
- [ ] **User Management**: Advanced user management tools for admins
- [ ] **Course Management**: Tools for managing courses, seats, and eligibility criteria
- [ ] **Application Processing**: Streamlined application review and approval process
- [ ] **Reports & Analytics**: Generate reports on applications, payments, and course statistics
- [ ] **Bulk Operations**: Support for bulk operations (approvals, rejections, notifications)

### 🎨 User Experience & Interface
- [x] **Progressive Form**: Implement step-by-step application form with progress tracking
- [ ] **Form Validation**: Real-time client-side validation with helpful error messages
- [ ] **Mobile Optimization**: Ensure responsive design for mobile devices
- [ ] **Loading States**: Add loading indicators and progress bars
- [ ] **Error Handling**: User-friendly error messages and recovery options
- [ ] **Accessibility**: Ensure WCAG compliance for accessibility

### 🔧 Technical Improvements
- [x] **REST API Architecture**: Complete REST API with proper serializers and views
- [x] **JWT Authentication**: JWT token-based authentication system implemented
- [x] **Database Models**: Comprehensive data models with proper relationships
- [ ] **Performance Optimization**: Optimize database queries and API response times
- [ ] **Caching**: Implement caching for frequently accessed data
- [ ] **API Documentation**: Generate comprehensive API documentation
- [ ] **Testing**: Add unit tests, integration tests, and end-to-end tests
- [ ] **Monitoring**: Add application monitoring and error tracking
- [ ] **Backup & Recovery**: Implement automated backup and recovery procedures
- [ ] **Deployment**: Set up CI/CD pipeline for automated deployments

### 📋 Compliance & Legal
- [ ] **Data Privacy**: Implement GDPR compliance features
- [ ] **Terms & Conditions**: Add terms and conditions acceptance tracking
- [ ] **Privacy Policy**: Implement privacy policy compliance
- [ ] **Data Retention**: Implement data retention and deletion policies
- [ ] **Audit Compliance**: Ensure compliance with educational institution requirements

## Setup Instructions

1. Clone the repository
2. Install dependencies: `pip install -r requirements.txt`
3. Run migrations: `python manage.py migrate`
4. Create superuser: `python manage.py createsuperuser`
5. Run the development server: `python manage.py runserver`

## Environment Variables

- `REGISTRATION_EXPIRY_HOURS`: Hours until registration session expires (default: 24)
- Database configuration variables
- Email and SMS service credentials for OTP delivery
