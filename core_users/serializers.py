from core_users.authentication_models import RegistrationSession, CustomUser
from core_users.models import UserApplication, EducationDetailsModel
from rest_framework import serializers


class RegisterSerializer(serializers.Serializer):
    """Serializer for starting Registration API View"""

    email = serializers.EmailField()
    phone = serializers.CharField(max_length=10)
    first_name = serializers.CharField(max_length=30)
    last_name = serializers.CharField(max_length=30)

    #TODO add validation for checking if the phone_number entered is a phone number


class VerifyOTPSerializer(serializers.Serializer):
    """Serializer for OTPVerification API View"""

    session_id = serializers.IntegerField()
    email_otp = serializers.CharField(max_length=6)
    phone_otp = serializers.CharField(max_length=6)


class ResendOTPSerializer(serializers.Serializer):
    """Serializer for Resending OTP API View"""

    email = serializers.EmailField()
    phone = serializers.CharField(max_length=10)

class SetPasswordSerializer(serializers.Serializer):
    """Serializer for saving Password"""

    session_id = serializers.IntegerField()
    password = serializers.CharField(write_only=True, min_length=8)
    confirm_password = serializers.CharField(write_only=True, min_length=8)

    def validate(self, data):
        if data['password'] != data['confirm_password']:
            raise serializers.ValidationError("Password and Confirm Password doesn't match")
        return data


class LoginSerializer(serializers.Serializer):
    """Serializer for login API View"""

    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)


class CustomUserSerializer(serializers.ModelSerializer):
    """Serializer for CustomUser API View"""

    class Meta:
        model = CustomUser
        fields = ['id', 'email', 'phone', 'first_name', 'last_name', 'is_admitted', 'admission_date']
        read_only_fields = ['id', 'is_admitted', 'admission_date']


class UserApplicationSerializer(serializers.ModelSerializer):
    """Serializer for UserApplication API view"""
    user = CustomUserSerializer(read_only=True)
    class Meta:
        model = UserApplication
        fields = '__all__'
        read_only_fields = ['id', 'application_id']

class UserEducationDetailSerializer(serializers.ModelSerializer):
    """Serializer for Education Details Model"""
    user = CustomUserSerializer(read_only=True)

    class Meta:
        model = EducationDetailsModel
        fields = '__all__'
        read_only_fields = ['id', 'user', 'user_application']

    def to_representation(self, instance):
        data = super().to_representation(instance)

        if instance.is_appearing:
            # Remove 12th marks fields if the student is still appearing
            for field in [
                'subject1_marks_12th',
                'subject2_marks_12th',
                'subject3_marks_12th',
                'subject4_marks_12th',
                'subject5_marks_12th',
                'subject6_marks_12th',
                'total_marks_12th',
            ]:
                data.pop(field, None)

        return data

