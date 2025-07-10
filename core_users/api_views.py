from django.template.context_processors import request
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken

from core_users.authentication_models import RegistrationSession, CustomUser
from core_users.models import UserApplication, EducationDetailsModel
from core_users.serializers import (
    RegisterSerializer,
    VerifyOTPSerializer,
    ResendOTPSerializer,
    SetPasswordSerializer,
    CustomUserSerializer,
    LoginSerializer,
    UserApplicationSerializer,
    UserEducationDetailSerializer
)
from core_main.services import OTPServices
from core_users.services import AuthenticationServices
from django.shortcuts import get_object_or_404
from rest_framework import permissions, status, generics
from rest_framework.views import APIView


class StartRegistrationAPIView(APIView):
    """API View for starting the user registration process"""
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        # PHASE 1: Validate incoming registration data
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        # Extract validated data
        email = data['email']
        phone = data['phone']
        first_name = data['first_name']
        last_name = data['last_name']

        # PHASE 2: Create registration session
        success, msg, session = AuthenticationServices.start_registration(email,
                                                                          phone,
                                                                          first_name,
                                                                          last_name)

        if not success:
            return Response({'detail': msg}, status=status.HTTP_400_BAD_REQUEST)

        # PHASE 3: Generate and send OTPs
        email_otp = OTPServices.generate_otp_record('email', email)
        phone_otp = OTPServices.generate_otp_record('phone', phone)
        OTPServices.send_email_otp(email, email_otp.otp_code)
        OTPServices.send_phone_otp(phone, phone_otp.otp_code)

        # PHASE 4: Return success response with session ID
        return Response({'session_id': session.id, 'detail': 'Registration Process Started! OTPs Sent'}, status=status.HTTP_201_CREATED)


class VerifyOTPAPIView(APIView):
    """API View for verifying email and phone OTPs"""
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        # PHASE 1: Validate incoming OTP data
        serializer = VerifyOTPSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        session_id = data['session_id']
        email_otp = data['email_otp']
        phone_otp = data['phone_otp']

        # PHASE 2: Retrieve registration session
        session = get_object_or_404(RegistrationSession, id=session_id)
        email = session.email
        phone = session.phone

        # PHASE 3: Verify both email and phone OTPs
        email_ok, email_msg = OTPServices.verify_otp('email', email, email_otp)
        phone_ok, phone_msg = OTPServices.verify_otp('phone', phone, phone_otp)

        # PHASE 4: Update verification status for successful OTPs
        if email_ok:
            AuthenticationServices.update_verification_status(session_id, 'email')
        if phone_ok:
            AuthenticationServices.update_verification_status(session_id, 'phone')

        # PHASE 5: Return appropriate response based on verification results
        if email_ok and phone_ok:
            return Response({'detail': 'Both OTPs verified.'}, status=status.HTTP_200_OK)

        return Response({'email_otp': email_msg, 'phone_otp': phone_msg}, status=status.HTTP_400_BAD_REQUEST)


class ResendOTPAPIView(APIView):
    """API View for resending OTPs to email and phone"""

    def post(self, request):
        # PHASE 1: Validate email and phone data
        serializer = ResendOTPSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        email = data['email']
        phone = data['phone']

        # PHASE 2: Generate new OTPs
        email_otp = OTPServices.generate_otp_record('email', email)
        phone_otp = OTPServices.generate_otp_record('phone', phone)

        # PHASE 3: Send OTPs via email and SMS
        OTPServices.send_email_otp(email, email_otp.otp_code)
        OTPServices.send_phone_otp(phone, phone_otp.otp_code)

        # PHASE 4: Return success response
        return Response({'detail': 'OTPs Sent'}, status=status.HTTP_201_CREATED)


class SetPasswordAPIView(APIView):
    """API View for completing registration by setting user password"""
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        # PHASE 1: Validate password data
        serializer = SetPasswordSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        session_id = data['session_id']
        password = data['password']
        confirm_password = data['confirm_password']

        # PHASE 2: Complete registration and create user account
        success, msg, user = AuthenticationServices.complete_registration(session_id, password)

        if not success:
            return Response({'detail': msg}, status=status.HTTP_400_BAD_REQUEST)

        # PHASE 3: Prepare response with user data
        response_data = {
            'detail': 'User Registered Successfully',
            'user': CustomUserSerializer(user).data
        }

        # PHASE 4: Return success response
        return Response(response_data, status=status.HTTP_201_CREATED)


class LoginAPIView(APIView):
    """API View for user authentication and login"""
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        # PHASE 1: Validate login credentials
        serializer = LoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        email = data['email']
        password = data['password']

        # PHASE 2: Retrieve user by email
        user = get_object_or_404(CustomUser, email=email)

        # PHASE 3: Verify password and generate tokens
        if user and user.check_password(password):
            refresh = RefreshToken.for_user(user)

            # PHASE 4: Prepare response with tokens and user data
            response_data = {
                'refresh': str(refresh),
                'access': str(refresh.access_token),
                'user': CustomUserSerializer(user).data,
            }

            return Response(response_data, status=status.HTTP_200_OK)

        # PHASE 5: Return error for invalid credentials
        return Response({'detail': 'Incorrect Password'}, status=status.HTTP_401_UNAUTHORIZED)


class CustomUserAPIView(generics.RetrieveAPIView):
    """API View for retrieving current user profile"""
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = CustomUserSerializer

    def get_object(self):
        return self.request.user


class UserApplicationAPIView(APIView):
    """API View for managing user application details"""

    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        """Retrieve user's application details"""
        # PHASE 1: Get user's application
        user_applications = get_object_or_404(UserApplication, user=request.user)
        
        # PHASE 2: Serialize and return data
        serializer = UserApplicationSerializer(user_applications)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def post(self, request):
        """Prevent POST requests - applications are auto-created"""
        return Response({'detail': 'User Application Already Exists. Use PUT to update.'}, status=status.HTTP_409_CONFLICT)

    def put(self, request):
        """Update user's application details"""
        # PHASE 1: Retrieve existing application
        application = get_object_or_404(UserApplication, user=request.user)

        # PHASE 2: Validate and update application data
        serializer = UserApplicationSerializer(application, data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save()  # automatically updates the application instance

        # PHASE 3: Return updated application data
        return Response({
            'detail': 'User Application Updated',
            'user_application': serializer.data
        }, status=status.HTTP_200_OK)


class UserEducationDetailsAPIView(APIView):
    """API View for managing user education details"""

    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        """Retrieve user's education details"""
        # PHASE 1: Get user's education details
        user_education_details = get_object_or_404(EducationDetailsModel, user=request.user)
        
        # PHASE 2: Serialize and return data
        serializer = UserEducationDetailSerializer(user_education_details)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def post(self, request):
        """Prevent POST requests - education details are auto-created"""
        return Response(
            {'detail': 'User Education Details Already Exists. Use PUT to update details'},
            status=status.HTTP_409_CONFLICT
        )

    def put(self, request):
        """Update user's education details"""
        # PHASE 1: Retrieve existing education details
        education_detail = get_object_or_404(EducationDetailsModel, user=request.user)

        # PHASE 2: Validate and update education data
        serializer = UserEducationDetailSerializer(education_detail, data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save()

        # PHASE 3: Return updated education details
        return Response({
            'detail': 'User Education Details Updated',
            'user_education_detail': serializer.data
        }, status=status.HTTP_200_OK)