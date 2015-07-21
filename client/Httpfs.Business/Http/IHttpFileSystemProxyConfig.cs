using System;

namespace httpfsc.Business.Http
{
    public interface IHttpFileSystemProxyConfig
    {
        #region Properties

        Url ServerRootPath { get; }

        #endregion
    }
}