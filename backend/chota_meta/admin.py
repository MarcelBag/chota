from django.contrib import admin
from .models import PlatformSettings, ScrapingLimits, ProxyConfig, FeatureFlag, UserPlan

@admin.register(PlatformSettings)
class PlatformSettingsAdmin(admin.ModelAdmin):
    def has_add_permission(self, request):
        return False if PlatformSettings.objects.exists() else True

@admin.register(ScrapingLimits)
class ScrapingLimitsAdmin(admin.ModelAdmin):
    def has_add_permission(self, request):
        return False if ScrapingLimits.objects.exists() else True

admin.site.register(ProxyConfig)
admin.site.register(FeatureFlag)
admin.site.register(UserPlan)
