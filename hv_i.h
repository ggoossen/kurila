
void
Perl_hv_store(pTHX_ HV* hv, const char *key, I32 klen, SV *val, U32 hash)
{
    hv_common_key_len(hv, key, klen,
        (HV_FETCH_ISSTORE|HV_FETCH_JUST_SV),
        val, hash);
}

void
Perl_hv_store_flags(pTHX_ HV *hv, const char *key, I32 klen, SV *val, U32 hash,
		    int flags)
{
    hv_common(hv, NULL, key, klen, flags,
        (HV_FETCH_ISSTORE|HV_FETCH_JUST_SV), val, hash);
}

void
Perl_hv_store_ent(pTHX_ HV *hv, SV *keysv, SV *val, U32 hash)
{
    hv_common(hv, keysv, NULL, 0, 0, HV_FETCH_ISSTORE, val, hash);
}

