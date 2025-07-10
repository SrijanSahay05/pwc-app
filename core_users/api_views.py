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
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        email = data['email']
        phone = data['phone']
        first_name= data['first_name']
        last_name = data['last_name']

        success, msg, session = AuthenticationServices.start_registration(email,
                                                                          phone,
                                                                          first_name,
                                                                          last_name)

        if not success:
            return Response({'detail' : msg}, status=status.HTTP_400_BAD_REQUEST)

        email_otp = OTPServices.generate_otp_record('email', email)
        phone_otp = OTPServices.generate_otp_record('phone', phone)
        OTPServices.send_email_otp(email, email_otp.otp_code)
        OTPServices.send_phone_otp(phone, phone_otp.otp_code)

        return Response({'session_id' : session.id, 'detail':'Registration Process Started! OTPs Sent'}, status=status.HTTP_201_CREATED)


class VerifyOTPAPIView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = VerifyOTPSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        session_id = data['session_id']
        email_otp = data['email_otp']
        phone_otp = data['phone_otp']

        session = get_object_or_404(RegistrationSession, id=session_id)
        email = session.email
        phone = session.phone

        email_ok, email_msg = OTPServices.verify_otp('email', email, email_otp)
        phone_ok, phone_msg = OTPServices.verify_otp('phone', phone, phone_otp)

        if email_ok:
            AuthenticationServices.update_verification_status(session_id, 'email')
        if phone_ok:
            AuthenticationServices.update_verification_status(session_id, 'phone')

        if email_ok and phone_ok:
            return  Response({'detail' : 'Both OTPs verified.'}, status=status.HTTP_200_OK)

        return Response({'email_otp': email_msg, 'phone_otp' : phone_msg}, status=status.HTTP_400_BAD_REQUEST)


class ResendOTPAPIView(APIView):
    """APIView to Resend OTPs"""

    def post(self, request):
        serializer = ResendOTPSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        email = data['email']
        phone = data['phone']

        email_otp = OTPServices.generate_otp_record('email', email)
        phone_otp = OTPServices.generate_otp_record('phone', phone)
        OTPServices.send_email_otp(email, email_otp.otp_code)
        OTPServices.send_phone_otp(phone, phone_otp.otp_code)

        return Response({ 'detail': 'OTPs Sent'}, status=status.HTTP_201_CREATED)


class SetPasswordAPIView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = SetPasswordSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        session_id = data['session_id']
        password = data['password']
        confirm_password = data['confirm_password']

        success, msg, user = AuthenticationServices.complete_registration(session_id, password)

        if not success:
            return Response({'detail': msg}, status=status.HTTP_400_BAD_REQUEST)

        response_data = {
            'detail' : 'User Registered Successfully',
            'user' : CustomUserSerializer(user).data
        }

        return Response(response_data, status=status.HTTP_201_CREATED)


class LoginAPIView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        email = data['email']
        password = data['password']

        user = get_object_or_404(CustomUser, email=email)

        if user and user.check_password(password):
            refresh = RefreshToken.for_user(user)

            response_data = {
                'refresh' : str(refresh),
                'access' : str(refresh.access_token),
                'user' : CustomUserSerializer(user).data,
            }

            return Response(response_data, status=status.HTTP_200_OK)

        return Response({'detail' : 'Incorrect Password'}, status=status.HTTP_401_UNAUTHORIZED)


class CustomUserAPIView(generics.RetrieveAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = CustomUserSerializer

    def get_object(self):
        return self.request.user


class UserApplicationAPIView(APIView):
    """all the userapplication related view logic goes here"""

    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        """Only fetch the user's application and returns the details"""
        user_applications = get_object_or_404(UserApplication, user=request.user)
        serializer = UserApplicationSerializer(user_applications)
        return Response(serializer.data, status=status.HTTP_200_OK)

    #TODO might not be used as the model already exists, so its better to use put ?
    def post(self, request):
        return Response({'detail' : 'User Application Already Exists. Use PUT to update.'}, status = status.HTTP_409_CONFLICT)


    def put(self, request):
        print("Put called for UserApplicationAPIView")
        application = get_object_or_404(UserApplication, user=request.user)

        serializer = UserApplicationSerializer(application, data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save()  # automatically updates the application instance

        return Response({
            'detail': 'User Application Updated',
            'user_application': serializer.data
        }, status=status.HTTP_200_OK)

class UserEducationDetailsAPIView(APIView):
    """All the UserEducationDetail API View logic goes here"""

    permission_classes = [permissions.IsAuthenticated]  # Ensure only logged-in users can access

    def get(self, request):
        """Fetch the user's education profile and return the details"""
        user_education_details = get_object_or_404(EducationDetailsModel, user=request.user)
        serializer = UserEducationDetailSerializer(user_education_details)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def post(self, request):
        return Response(
            {'detail': 'User Education Details Already Exists. Use PUT to update details'},
            status=status.HTTP_409_CONFLICT
        )

    def put(self, request):
        print("Put called for UserEducationDetailsAPIView")
        education_detail = get_object_or_404(EducationDetailsModel, user=request.user)

        serializer = UserEducationDetailSerializer(education_detail, data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save()

        return Response({
            'detail': 'User Education Details Updated',
            'user_education_detail': serializer.data
        }, status=status.HTTP_200_OK)