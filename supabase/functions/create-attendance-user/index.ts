import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const allowedRoles = new Set([
  "doctor",
  "nurse",
  "paramedic",
  "secretary",
  "driver",
  "pharmacist",
  "employee",
  "admin",
]);

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) return json({ error: "Server is not configured" }, 500);

  const adminClient = createClient(supabaseUrl, serviceRoleKey);
  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return json({ error: "يجب تسجيل الدخول كمدير" }, 401);
  }

  const token = authorization.slice("Bearer ".length);
  const { data: authData, error: authError } = await adminClient.auth.getUser(token);
  if (authError || !authData.user) return json({ error: "جلسة الدخول غير صالحة" }, 401);

  const { data: adminUser, error: adminError } = await adminClient
    .from("attendance_users")
    .select("role, job_title")
    .eq("id", authData.user.id)
    .maybeSingle();
  if (
    adminError ||
    !adminUser ||
    (adminUser.role !== "admin" && adminUser.job_title !== "مدير النظام")
  ) {
    return json({ error: "ليس لديك صلاحية إضافة مستخدمين" }, 403);
  }

  let payload: Record<string, unknown>;
  try {
    payload = await request.json();
  } catch {
    return json({ error: "بيانات الطلب غير صحيحة" }, 400);
  }

  const username = String(payload.username ?? "").trim();
  const password = String(payload.password ?? "");
  const fullName = String(payload.full_name ?? "").trim();
  const employeeNumber = String(payload.employee_number ?? "").trim();
  const jobTitle = String(payload.job_title ?? "").trim();
  const role = String(payload.role ?? "").trim();
  const department = String(payload.department ?? "").trim() || null;
  const phone = String(payload.phone ?? "").trim() || null;

  if (!/^[A-Za-z0-9_.-]{3,40}$/.test(username)) {
    return json({ error: "اسم المستخدم يجب أن يكون 3-40 حرفًا إنجليزيًا أو رقمًا" }, 400);
  }
  if (password.length < 6) return json({ error: "كلمة المرور يجب أن تكون 6 أحرف على الأقل" }, 400);
  if (!fullName || !employeeNumber) return json({ error: "الاسم والرقم الوظيفي مطلوبان" }, 400);
  if (jobTitle.length < 2 || jobTitle.length > 100) {
    return json({ error: "اسم الوظيفة يجب أن يكون بين حرفين و100 حرف" }, 400);
  }
  if (!allowedRoles.has(role)) return json({ error: "الدور غير صالح" }, 400);
  if (role === "admin" && jobTitle !== "مدير النظام") {
    return json({ error: "دور المدير يتطلب المسمى مدير النظام" }, 400);
  }
  if (jobTitle === "مدير النظام" && role !== "admin") {
    return json({ error: "مسمى مدير النظام مخصص لدور المدير فقط" }, 400);
  }

  const { data: existingUsername } = await adminClient
    .from("profiles")
    .select("id")
    .ilike("username", username)
    .maybeSingle();
  if (existingUsername) return json({ error: "اسم المستخدم مستخدم بالفعل" }, 409);

  const { data: existingEmployee } = await adminClient
    .from("attendance_users")
    .select("id")
    .eq("employee_number", employeeNumber)
    .maybeSingle();
  if (existingEmployee) return json({ error: "الرقم الوظيفي مستخدم بالفعل" }, 409);

  const internalEmail = `${username.toLowerCase()}@attendance.local`;
  const { data: createdAuth, error: createAuthError } = await adminClient.auth.admin.createUser({
    email: internalEmail,
    password,
    email_confirm: true,
    user_metadata: { username, full_name: fullName },
  });
  if (createAuthError || !createdAuth.user) {
    return json({ error: createAuthError?.message ?? "تعذّر إنشاء مستخدم Auth" }, 400);
  }

  const userId = createdAuth.user.id;
  const { error: profileError } = await adminClient.from("profiles").insert({
    id: userId,
    username,
    full_name: fullName,
    role,
    email: internalEmail,
  });
  const { error: attendanceError } = profileError
    ? { error: profileError }
    : await adminClient.from("attendance_users").insert({
        id: userId,
        full_name: fullName,
        employee_number: employeeNumber,
        phone,
        job_title: jobTitle,
        department,
        role,
      });

  if (profileError || attendanceError) {
    await adminClient.from("attendance_users").delete().eq("id", userId);
    await adminClient.from("profiles").delete().eq("id", userId);
    await adminClient.auth.admin.deleteUser(userId);
    return json({ error: "تعذّر ربط المستخدم بجداول النظام" }, 400);
  }

  return json({ success: true, user_id: userId });
});